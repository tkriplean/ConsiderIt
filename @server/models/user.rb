require 'open-uri'

class User < ActiveRecord::Base
  has_secure_password validations: false
  alias_attribute :password_digest, :encrypted_password

  has_many :points, :dependent => :destroy
  has_many :opinions, :dependent => :destroy
  has_many :inclusions, :dependent => :destroy
  has_many :comments, :dependent => :destroy
  has_many :proposals
  has_many :notifications, :dependent => :destroy

  attr_accessor :avatar_url, :downloaded

  before_validation :download_remote_image, :if => :avatar_url_provided?
  before_save do 
    self.email = self.email.downcase if self.email

    self.name = sanitize_helper self.name if self.name   
    self.bio = sanitize_helper if self.bio
  end

  #validates_presence_of :avatar_remote_url, :if => :avatar_url_provided?, :message => 'is invalid or inaccessible'
  after_create :add_token

  has_attached_file :avatar, 
      :styles => { 
        :large => "250x250#",
        :small => "50x50#"
      },
      :processors => [:thumbnail, :compression]

  process_in_background :avatar

  after_post_process do 
    if self.avatar.queued_for_write[:small]

      img_data = self.avatar.queued_for_write[:small].read

      self.avatar.queued_for_write[:small].rewind
      data = Base64.encode64(img_data)
      b64_thumbnail = "data:image/jpeg;base64,#{data.gsub(/\n/,' ')}"

      begin        
        qry = "UPDATE users SET b64_thumbnail='#{b64_thumbnail}' WHERE id=#{self.id}"
        ActiveRecord::Base.connection.execute(qry)
      rescue => e
        raise "Could not store image for user #{self.id}, it is too large!"
      end

      Oj.load((self.active_in or '[]')).each do |subdomain_id|
        Rails.cache.delete("avatar-digest-#{subdomain_id}") 
      end
    end
  end

  validates_attachment_content_type :avatar, :content_type => %w(image/jpeg image/jpg image/png image/gif)


  # This will output the data for this user _as if this user is currently logged in_
  # So make sure to only send this data to the client if the client is authorized. 
  def current_user_hash(form_authenticity_token)
    data = {
      id: id, #leave the id in for now for backwards compatability with Dash
      key: '/current_user',
      user: "/user/#{id}",
      logged_in: registered,
      email: email,
      password: nil,
      csrf: form_authenticity_token,
      avatar_remote_url: avatar_remote_url,
      url: url,
      name: name,
      reset_password_token: nil,
      b64_thumbnail: b64_thumbnail,
      tags: Oj.load(tags || '{}'),
      is_super_admin: self.super_admin,
      is_admin: is_admin?,
      is_moderator: permit('moderate content', nil) > 0,
      is_evaluator: permit('factcheck content', nil) > 0,
      trying_to: nil,
      subscriptions: subscription_settings(current_subdomain),
      notifications: notifications.order('created_at desc'),
      verified: verified,
      needs_to_complete_profile: self.registered && (self.complete_profile || !self.name),
                                #happens for users that were created via email invitation
      needs_to_verify: ['bitcoin', 'bitcoinclassic'].include?(current_subdomain.name) && \
                               self.registered && !self.verified

    }

    data
    
  end

  # Gets all of the users active for this subdomain
  def self.all_for_subdomain
    fields = "CONCAT('\/user\/',id) as 'key',users.name,users.avatar_file_name,users.tags"
    if current_user.is_admin?
      fields += ",email"
    end
    if current_subdomain.name == 'homepage'
      users = ActiveRecord::Base.connection.exec_query( "SELECT #{fields} FROM users WHERE registered=1")
    else 
      users = ActiveRecord::Base.connection.exec_query( "SELECT #{fields} FROM users WHERE registered=1 AND active_in like '%\"#{current_subdomain.id}\"%'")
    end 
    # if current_user.is_admin?
    users.each{|u| u['tags']=Oj.load(u['tags']||'{}')}      
    # end

    {key: '/users', users: users.as_json}
  end

  # Note: This is barely used in practice, because most users are
  # generated by the all_for_subdomain() method above.
  def as_json(options={})
    result = { 'key' => "/user/#{id}",
               'name' => name,
               'avatar_file_name' => avatar_file_name,
               'tags' => Oj.load(tags || '{}')  }
                  # TODO: filter private tags
    if current_user.is_admin?
      result['email'] = email
    end
    result
  end

  def is_admin?(subdomain = nil)
    subdomain ||= current_subdomain
    has_any_role? [:admin, :superadmin], subdomain
  end

  def has_role?(role, subdomain = nil)
    role = role.to_s

    if role == 'superadmin'
      return self.super_admin
    else
      subdomain ||= current_subdomain
      roles = subdomain.roles ? Oj.load(subdomain.roles) : {}
      return roles.key?(role) && roles[role] && roles[role].include?("/user/#{id}")
    end
  end

  def has_any_role?(roles, subdomain = nil)
    subdomain ||= current_subdomain
    for role in roles
      return true if has_role?(role, subdomain)
    end
    return false
  end

  def logged_in?
    # Logged-in now means that the current user account is registered
    self.registered
  end

  def add_to_active_in(subdomain=nil)
    subdomain ||= current_subdomain
    
    active_subdomains = Oj.load(self.active_in || "[]")

    if !active_subdomains.include?("#{subdomain.id}")
      active_subdomains.push "#{subdomain.id}"
      self.active_in = JSON.dump active_subdomains
      self.save

      # if we're logging in to a subdomain that we didn't originally register, we'll have to 
      # regenerate the avatars file. Note that there is still a bug where the avatar won't be there 
      # on initial login to the new subdomain.
      if self.avatar_file_name && active_subdomains.length > 1
        subdomain_id = subdomain.id
        Rails.cache.delete("avatar-digest-#{subdomain_id}")
      end
    end

  end

  def emails_received
    Oj.load(self.emails || "{}")
  end

  def sent_email_about(key, time=nil)
    time ||= Time.now().to_s
    settings = emails_received
    settings[key] = time
    self.emails = JSON.dump settings
    self.save
  end


  # Notification preferences. 
  def subscription_settings(subdomain)

    notifier_config = Notifier::config
    my_subs = Oj.load(subscriptions || "{}")[subdomain.id.to_s] || {}

    for event, config in notifier_config
      if config.key? 'allowed'
        next if !config['allowed'].call(self, subdomain)
      end
      
      if my_subs.key?(event)
        my_subs[event].merge! config
      else 
        my_subs[event] = config
      end

      if !my_subs[event].key?('email_trigger')
        my_subs[event]['email_trigger'] = my_subs[event]['email_trigger_default']
      end

    end

    my_subs['default_subscription'] = Notifier.default_subscription
    if !my_subs.key?('send_emails')
      my_subs['send_emails'] = my_subs['default_subscription']
    end

    my_subs
  end

  def update_subscription_key(key, value, hash={})
    sub_settings = subscription_settings(current_subdomain)
    return if !hash[:force] && sub_settings.key?(key)

    sub_settings[key] = value
    self.subscriptions = update_subscriptions(sub_settings)
    save
  end

  def update_subscriptions(new_settings, subdomain = nil)
    subdomain ||= current_subdomain

    subs = Oj.load(subscriptions || "{}")
    subs[subdomain.id.to_s] = new_settings

    # Strip out unnecessary items that we can reconstruct from the 
    # notification configuration 
    clean = proc do |k, v|        

      if v.respond_to?(:key?)
        if v.key?('default_subscription') && 
            v['default_subscription'] == v['subscription']
          v.delete('subscription')
        elsif v.key?('default_email_trigger') && 
            v['default_email_trigger'] == v['email_trigger']
          v.delete('email_trigger')
        end

        v.delete_if(&clean) # recurse if v is a hash
      end

      # 'proposal' and 'subdomain' in the list below is temporary for some migrations...
      # feel free to remove junish
      v.respond_to?(:key) && v.keys().length == 0 || \
      ['proposal', 'subdomain', 'subscription_options', 'ui_label', \
       'default_subscription', 'default_email_trigger'].include?(k)

    end

    subs.delete_if &clean

    JSON.dump subs
  end

  def avatar_url_provided?
    !self.avatar_url.blank?
  end

  def download_remote_image
    if self.downloaded.nil?
      self.downloaded = true
      self.avatar_url = self.avatar_remote_url if avatar_url.nil?
      io = open(URI.parse(self.avatar_url))
      def io.original_filename; base_uri.path.split('/').last; end

      self.avatar = io if !(io.original_filename.blank?)
      self.avatar_remote_url = avatar_url
      self.avatar_url = nil
    end

  end


  def key
    "/user/#{self.id}"
  end

  def username
    name ? 
      name
      : email ? 
        email.split('@')[0]
        : "#{current_subdomain.app_title or current_subdomain.name} participant"
  end
  
  def first_name
    username.split(' ')[0]
  end

  def short_name
    split = username.split(' ')
    if split.length > 1
      return "#{split[0][0]}. #{split[-1]}"
    end
    return split[0]  
  end


  def add_token
    self.unique_token = SecureRandom.hex(10)
    self.save
  end

  def self.add_token
    User.where(:unique_token => nil).each do |u|
      u.unique_token
    end
  end

  def avatar_link(img_type='small')
    if self.avatar_file_name
      "#{Rails.application.config.action_controller.asset_host || ''}/system/avatars/#{self.id}/#{img_type}/#{self.avatar_file_name}"
    else 
      nil 
    end
  end


  def absorb (user)
    return if not (self and user)

    older_user = self.id #user that will do the absorbing
    newer_user = user.id #user that will be absorbed

    puts("Merging!  Kill User #{newer_user}, put into User #{older_user}")

    return if older_user == newer_user
    
    dirty_key("/current_user") # in case absorb gets called outside 
                               # of CurrentUserController

    # Not only do we need to merge the user objects, but we'll need to
    # merge their opinion objects too.

    # To do this, we take the following steps
    #  1. Merge both users' opinions
    #  2. Change user_id for every object that has one to the new user_id
    #  3. Delete the old user

    # 1. Merge opinions
    #    ASSUMPTION: The Opinion of the user being absorbed is _newer_ than 
    #                the Opinion of the user doing the absorbtion. 
    #                This is currently TRUE for considerit. 
    #    TODO: Reconsider this assumption. Should we use Opinion.updated_at to 
    #          decide which is the new one and which is the old, and consequently 
    #          which gets absorbed into the other?
    new_ops = Opinion.where(:user_id => newer_user)
    old_ops = Opinion.where(:user_id => older_user)
    puts("Merging opinions from #{old_ops.map{|o| o.id}} to #{new_ops.map{|o| o.id}}")

    for new_op in new_ops

      # we only need to absorb this user if they've dragged the slider 
      # or included a point
      # ATTENTION!! This will delete someone's opinion if they vote exactly neutral and 
      #             didn't include any points (and they're logging in)
      if new_op.stance == 0 && (new_op.point_inclusions == '[]' || new_op.point_inclusions.length == 0)
        new_op.destroy
        next 
      end

      puts("Looking for opinion to absorb into #{new_op.id}...")
      old_op = Opinion.where(:user_id => older_user,
                             :proposal_id => new_op.proposal.id).first

      if old_op
        puts("Found opinion to absorb into #{new_op.id}: #{old_op.id}")
        # Merge the two opinions. We'll absorb the old opinion into the new one!
        # Update new_ops' user_id to the old user. 
        new_op.absorb(old_op, true)
      else
        # if this is the first time this user is saving an opinion for this proposal
        # we'll just change the user id of the opinion, seeing as there isn't any
        # opinion to absorb into
        new_op.user_id = older_user
        new_op.save
        dirty_key("/opinion/#{new_op.id}")
      end
      
    end

    # 2. Change user_id columns over in bulk
    # TRAVIS: Opinion & Inclusion is taken care of when absorbing an Opinion

    # Bulk updates...
    for table in [Point, Proposal, Comment] 

      # First, remember what we're dirtying
      table.where(:user_id => newer_user).each{|x| dirty_key("/#{table.name.downcase}/#{x.id}")}
      table.where(:user_id => newer_user).update_all(user_id: older_user)
    end

    # log table, which doesn't use user_id
    Log.where(:who => newer_user).update_all(who: older_user)

    subs = Oj.load(self.active_in || '[]').concat(Oj.load(user.active_in || '[]')).uniq
    self.active_in = JSON.dump subs
    save 

    # 3. Delete the old user
    # TODO: Enable this once we're confident everything is working.
    #       I see that this is being done in CurrentUserController#replace_user. 
    #       Where should it live? 
    # user.destroy()

  end

  def self.refresh_cache (subdomain = nil)
    if subdomain
      subdomains = [subdomain]
    else 
      subdomains = Subdomain.all
    end
    for subdomain in subdomains 
      pp "Updating avatar cache for #{subdomain.name}"
      cache_key = "avatar-digest-#{subdomain.id}"
      users = User.where("registered=1 AND b64_thumbnail IS NOT NULL AND INSTR(active_in, '\"#{subdomain.id}\"')")
      avatars = users.select([:id,:b64_thumbnail]).map {|user| "#avatar-#{user.id} { background-image: url('#{user.b64_thumbnail}');}"}.join(' ')
      Rails.cache.write(cache_key, avatars)
    end
  end

  def self.purge
    users = User.all.map {|u| u.id}
    missing_users = []
    classes = [Opinion, Point, Inclusion]
    classes.each do |cls|
      cls.where("user_id IS NOT NULL AND user_id NOT IN (?)", users ).each do |r|
        missing_users.push r.user_id
      end
    end
    classes.each do |cls|
      cls.where("user_id in (?)", missing_users.uniq).delete_all
    end

  end
   

end
