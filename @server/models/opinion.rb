class Opinion < ActiveRecord::Base
  belongs_to :user
  belongs_to :proposal, :touch => true 
  
  include Followable

  acts_as_tenant :subdomain

  scope :published, -> {where( :published => true )}
  scope :public_fields, -> {select( [:created_at, :updated_at, :id, :proposal_id, :stance, :stance_segment, :user_id, :point_inclusions, :published] )}

  before_save do 
    self.explanation = self.explanation.sanitize if self.explanation
    self.stance_segment = Opinion.get_segment(self.stance)
  end 

  def as_json(options={})
    pubs = ['created_at', 'updated_at', 'id', 'point_inclusions',
            'proposal_id', 'stance', 'stance_segment', 'user_id', 'explanation',
            'published']

    result = super(options)
    result = result.select{|k,v| pubs.include? k}

    make_key(result, 'opinion')
    stubify_field(result, 'user')
    stubify_field(result, 'proposal')
    result['point_inclusions'] = JSON.parse (result['point_inclusions'] || '[]')
    result['point_inclusions'].map! {|p| "/point/#{p}"}
    result
  end

  def self.get_or_make(proposal, user)
    # Each (user,proposal) should have only one opinion.

    if !user
      raise "Need a user to get their opinion!"
    end
    
    # First try to find a published opinion for this user
    your_opinion = Opinion.where(:proposal_id => proposal.id, 
                                 :user => user)
    if your_opinion.length > 1
      raise "Duplicate opinions for user #{user}: #{your_opinion.map {|o| o.id} }!"
    end
    your_opinion = your_opinion.first

    # Otherwise create one
    if your_opinion.nil?
      your_opinion = Opinion.create(:proposal_id => proposal.id,
                                    :user => user ? user : nil,
                                    :subdomain_id => Thread.current[:subdomain].id,
                                    :published => false,
                                    :stance => 0,
                                    :point_inclusions => '[]',
                                    :explanation => ''
                                   )
    end
    your_opinion
  end

  def publish
    return if self.published

    self.published = true
    recache
    self.save if changed?

    # When we publish an opinion, all the points the user wrote on
    # this opinion/proposal become published too
    Point.where(:user_id => self.user_id,
                :proposal_id => self.proposal_id).each {|p| p.publish()}

    # New opinion means the proposal needs to be re-fetched so that
    # it includes it in its list of stuff
    dirty_key "/page/#{Proposal.find(proposal_id).slug}"

    # ActiveSupport::Notifications.instrument("published_new_opinion", 
    #                                         :opinion => self,
    #                                         :current_subdomain => Thread.current[:subdomain],
    #                                         :mail_options => Thread.current[:mail_options])
    # send out confirmation email if user is not yet confirmed
    # if !current_user.confirmed? && current_user.opinions.published.count == 1
    #   ActiveSupport::Notifications.instrument("first_opinion_by_new_user", 
    #     :user => current_user,
    #     :proposal => proposal,
    #     :current_subdomain => current_subdomain,
    #     :mail_options => mail_options
    #   )
    # end
  end

  def update_inclusions (points_to_include)
    points_already_included = inclusions.map {|i| i.point_id}
    points_to_exclude = points_already_included.select {|point_id| not points_to_include.include? point_id}
    points_to_add    = points_to_include.select {|p_id| not points_already_included.include? p_id }

    puts("Excluding points #{points_to_exclude}, including points #{points_to_add}")

    # Delete goners
    points_to_exclude.each do |point_id|
      self.exclude point_id
    end
    
    # Add newbies
    points_to_add.each do |point_id|
      self.include point_id
    end

    # Return the points that were not touched in this process
    # These points are used in the absorb method. 
    points_to_include.select {|p_id| points_already_included.include? p_id }
  end


  def include(point)
    if not point.is_a? Point
      point = Point.find point
    end

    dirty_key("/point/#{point.id}")
    dirty_key("/opinion/#{self.id}")

    user = User.find(self.user_id)

    if user.inclusions.where( :point_id => point.id ).count > 0
      Rails.logger.error "Including a point (#{point.id}) for user #{self.user_id} twice!'"
      return
    end
    
    attrs = { 
      :point_id => point.id,
      :user_id => self.user_id,
      :proposal_id => self.proposal_id,
      :subdomain_id => Thread.current[:subdomain].id
    }
    Inclusion.create! attrs

    point.follow! user, :follow => true, :explicit => false
    point.recache
    self.recache
  end    

  def exclude(point)
    if not point.is_a? Point
      point = Point.find point
    end
    dirty_key("/point/#{point.id}")
    dirty_key("/opinion/#{self.id}")

    user = User.find(self.user_id)
    inclusion = user.inclusions.find_by_point_id point.id

    inclusion.destroy
    point.follow! user, :follow => false, :explicit => false
    point.recache
    self.recache
  end
  
  def absorb( opinion, absorb_user = false)

    # First record everything we're dirtying and remapping
    dirty_key("/opinion/#{id}")
    remap_key("/opinion/#{opinion.id}", "/opinion/#{id}")
    dirty_key("/page/#{Proposal.find(proposal_id).slug}")    

    # If we're absorbing the Opinion's user as well
    if absorb_user
      puts("Changing user for Opinion #{id} to #{opinion.user_id}")

      # We only have to update inclusions if the user is changing because
      # inclusions are identified by (proposal_id, user_id), not by Opinion.
      new_inclusions = self.proposal.inclusions.where(:user_id => opinion.user_id)
      all_inclusions = ( inclusions.map{|i| i.point.id} \
                    + new_inclusions.map{|i| i.point.id}).uniq

      proposal.inclusions.where(:user_id => self.user_id).destroy_all

      self.user_id = opinion.user_id # Do this after getting all_inclusions, but before update_inclusions.
      not_recached = self.update_inclusions(all_inclusions) # And this will recached
      not_recached.each do |pnt_id|
        Point.find(pnt_id).recache
      end
    end

    puts("Absorbing opinion #{opinion.id} into #{self.id}")

    # Copy the stance of the opinion if the opinion is older
    # (Picking the older one because of a bug where if you
    # login on a proposal page, it will replace your old opinion
    # with the new neutral one)
    if opinion.updated_at < updated_at && opinion.published
      self.stance = opinion.stance
      self.stance_segment = opinion.stance_segment
    end

    # If something was published, ensure everything is published
    self.publish() if self.published or opinion.published

    opinion.destroy()
    recache

  end

  def recache
    self.point_inclusions = inclusions.select(:point_id).map {|x| x.point_id }.uniq.compact.to_s
    self.save
  end

  def inclusions
    Inclusion.where(:proposal_id => proposal_id, :user_id => user_id)
  end

  def self.get_segment(value)
    if value == -1
      return 0
    elsif value == 1
      return 6
    elsif value <= 0.05 && value >= -0.05
      return 3
    elsif value >= 0.5
      return 5
    elsif value <= -0.5
      return 1
    elsif value >= 0.05
      return 4
    elsif value <= -0.05
      return 2
    end   
  end

  # This is a maintenance function.  You shouldn't need to run it
  # anymore, because the database shouldn't contain duplicate opinions
  # anymore.
  def self.remove_duplicate_opinions
    User.find_each do |u|
      proposals = u.opinions.map {|p| p.proposal_id}.uniq
      proposals.each do |prop|
        ops = u.opinions.where(:proposal_id => prop)
        # Let's find the most recent
        ops = ops.sort {|a,b| a.updated_at <=> b.updated_at}
        # And purge all but the last
        pp("We found #{ops.length-1} duplicates for user #{u.id}")
        ops.each do |op|
          if op.id != ops.last.id
            pp("We are deleting opinion #{op.id}, cause it is not the most recent: #{ops.last.id}.")
            op.delete
          end
        end
      end
    end

    # And cause I want this too
    Point.all.each do |p|
      if p.published
        puts("Fixing #{p.id}")
      end
      p.recache(true)
    end
    'done'
  end

  def self.purge
    Opinion.where('user_id IS NULL').destroy_all
    
    User.find_each do |u|
      proposals = u.opinions.map {|p| p.proposal_id}.uniq
      proposals.each do |prop|
        pos = u.opinions.where(:proposal_id => prop)
        if pos.where(:published => true).count > 1
          last = pos.order(:updated_at).last
          pos.where('id != (?)', last.id).each do |p|
            p.published = false
            p.save
          end
        end
      end
    end
  end


end



