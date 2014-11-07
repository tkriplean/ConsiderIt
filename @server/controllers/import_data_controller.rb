require 'csv'


# Imports data from CSVs
# Limitations:
#   - proposals don't upload additional description
#   - can only import comments if they refer to a point described in this batch

class ImportDataController < ApplicationController
  rescue_from CanCan::AccessDenied do |exception|
    result = {
      :errors => [current_user.nil? ? 'not logged in' : 'not authorized']
    }
    render :json => result 
    return
  end


  def create
    if !access
      raise new CanCan::AccessDenied
    end

    errors = []
    modified = {}

    points = {}

    configuration = {
      'users' => {
        required_fields: ['name', 'email'],
        directly_extractable: ['name', 'email']
      },
      'proposals' => {
        required_fields: ['url', 'topic', 'user'],
        directly_extractable: ['description', 'cluster', 'seo_title', 'seo_description', 'seo_keywords']
      },
      'opinions' => {
        required_fields: ['user', 'proposal', 'stance'],
        directly_extractable: ['stance']
      },
      'points' => {
        required_fields: ['id', 'user', 'proposal', 'nutshell', 'is_pro'],
        directly_extractable: ['nutshell', 'text']
      },      
      'comments' => {
        required_fields: ['user', 'point', 'body'],
        directly_extractable: ['body']
      }
    }


    # wrap everything in a transaction so that we can rollback _everything_ in the case of errors
    ActiveRecord::Base.transaction do

      # Now loop back through to create objects
      # The order of the tables matters
      for table in ['users', 'proposals', 'opinions', 'points', 'comments']
        file = params["#{table}-file"]
        next if !file || file == ''

        modified[table] = []

        config = configuration[table]
        checked_required_fields = false

        CSV.foreach(file.tempfile, :headers => true, :encoding => 'windows-1251:utf-8') do |row|
          error = false

          # Make sure that this file has all the required columns           
          if !checked_required_fields
            missing_fields = []
            config[:required_fields].each do |rq|
              if !row.has_key?(rq)
                missing_fields.append rq
              end 
            end
            if missing_fields.length > 0 
              # not worth continuing to parse if required fields are missing in the schema
              errors.append "#{table} file is missing required columns: #{missing_fields.join(', ')}"
              break
            else 
              checked_required_fields = true
            end
          end

          # Make sure this row has values for each required field
          empty_required_fields = []
          config[:required_fields].each do |rq|
            if row[rq] == ''
              empty_required_fields.append rq
            end
          end
          if empty_required_fields.length > 0
            error = true
            errors.append "#{table} file has some empty entries for the #{rq} field"
          end

          # Find each required relational object
          if config[:required_fields].include? 'user'
            user = User.find_by_email(row['user'].downcase)
            if !user
              errors.append "#{table} file: could not find a User with an email #{row['user']}. Did you forget to add #{row['user']} to the User file?"
              error = true
            end
          end

          if config[:required_fields].include? 'proposal'
            proposal = Proposal.find_by_long_id(row['proposal'].gsub(' ', '_').gsub(',','_').gsub('.','').downcase)
            if !proposal
              errors.append "#{table} file: could not find a Proposal associated with #{row['proposal']}. Did you forget to add #{row['proposal']} to the Proposal file?"
              error = true
            end
          end

          if config[:required_fields].include? 'point'
            # Comments will refer to a point by a made up id field. Points are indexed by their 
            # ID in the points hash. These IDs do not correspond to the database. Comments
            # for now can only be added to points that are identified in the same batch of uploaded CSVs.
            
            point = points.has_key?(row['point']) ? points[row['point']] : nil
            if !point
              errors.append "#{table} file: could not find a Point associated with #{row['point']}. Did you forget to add a Point with id #{row['point']} to the Point file?"
              error = true
            end
          end

          next if error

          # Grab all of the easily extracted attributes
          attrs = row.to_hash.select{|k,v| config[:directly_extractable].include? k}

          # The rest has to be handled on a table by table basis
          case table
          when 'users'
            user = User.find_by_email row['email'].downcase

            if row.has_key? 'avatar'
              attrs['avatar_url'] = row['avatar']
            end

            if !user
              attrs['password'] = SecureRandom.base64(15).tr('+/=lIO0', 'pqrsxyz')[0,20] 
              user = User.new attrs
              user.save
              modified[table].push "Created User '#{user.name}'"
            else 
              user.update_attributes attrs
              modified[table].push "Updated User '#{user.name}'"              
            end
            user.add_to_active_in

          when 'proposals'

            attrs.update({
              'long_id' => row['url'].gsub(' ', '_').gsub(',','_').gsub('.','').downcase,
              'user_id' => user.id,
              'name' => row['topic'],
              'published' => true
            })

            proposal = Proposal.find_by_long_id attrs['long_id']
            if !proposal
              attrs['account_id'] = current_tenant.id
              proposal = Proposal.new attrs
              proposal.save
              modified[table].push "Created Proposal '#{proposal.name}'"
            else
              proposal.update_attributes attrs
              modified[table].push "Updated Proposal '#{proposal.name}'"              
            end



          when 'opinions'
            opinion = Opinion.where(:user_id => user.id, :proposal_id => proposal.id).first
            attrs.update({
              'proposal_id' => proposal.id,
              'user_id' => user.id,
            })

            # we'll assume that if we're creating an opinion for a user that the user should 
            # be registered
            if !user.registration_complete
              user.registration_complete = true
              user.save
            end

            if !opinion
              attrs['account_id'] = current_tenant.id
              opinion = Opinion.new attrs
              opinion.publish
              modified[table].push "Created Opinion by #{user.name} on '#{proposal.name}'"
            else
              opinion.update_attributes attrs
              opinion.recache
              modified[table].push "Updated Opinion by #{user.name} on '#{proposal.name}'"
            end

          when 'points'

            opinion = Opinion.where(:user_id => user.id, :proposal_id => proposal.id).first
            if !opinion
              error.push "A Point written by #{user.email} does not have an associated Opinion. Please add an Opinion for this user to the Opinions file!"
              next
            end

            attrs.update({
                        'proposal_id' => proposal.id,
                        'user_id' => user.id,
                        'published' => true,
                        'is_pro' => ['1', 'true'].include?(row['is_pro'].downcase)
                      })
            point = Point.find_by_nutshell(attrs['nutshell'])
            if !point
              attrs['account_id'] = current_tenant.id
              point = Point.new attrs
              point.save
              modified[table].push "Created Point '#{point.nutshell}'"
            else
              point.update_attributes attrs
              modified[table].push "Updated Point '#{point.nutshell}'"
            end

            opinion.include point
            point.recache
            points[row['id']] = point
            

          when 'comments'
            attrs.update({
              'point_id' => point.id,
              'user_id' => user.id,
              'commentable_type' => 'Point',
              'commentable_id' => point.id
            })

            comment = Comment.where(:point_id => point.id, :user_id => user.id, :body => attrs['body'] ).first
            if !comment
              attrs['account_id'] = current_tenant.id
              comment = Comment.new attrs
              comment.save
              modified[table].push "Created Comment '#{comment.body}'"
            else 
              comment.update_attributes attrs
              modified[table].push "Updated Comment '#{comment.body}'"
            end
            point.recache

          end
        end

      end

      if errors.length > 0
        raise ActiveRecord::Rollback
      end
    end

    if errors.length > 0
      render :json => [{'errors' => errors.uniq}]
    else
      Point.delay.update_scores
      render :json => [modified]
    end

  end

  # # only for LVG
  # def self.import_jurisdictions(proposals_file, jurisdictions_file)
  #   jurisdiction_to_proposals = {}
  #   errors = []

  #   CSV.foreach(proposals_file.tempfile, :headers => true) do |row|
  #     proposal = Proposal.find_by_long_id(row['long_id'])
  #     if !proposal
  #       errors.push "Could not find proposal #{row['long_id']}"
  #       next
  #     end
  #     jurisdiction = row['jurisdiction'].split.map(&:capitalize).join(' ')
  #     if jurisdiction == 'Statewide'
  #       proposal.add_tag 'type:statewide'
  #       proposal.add_tag "jurisdiction:State of Washington"
  #       proposal.add_seo_keyword 'Statewide'
  #       proposal.save
  #       next
  #     end

  #     if !(jurisdiction_to_proposals.has_key?(jurisdiction))
  #       jurisdiction_to_proposals[jurisdiction] = []
  #     end

  #     jurisdiction_to_proposals[jurisdiction].push proposal
  #   end

  #   jurisdiction_to_zips = {}
  #   CSV.foreach(jurisdictions_file.tempfile, :headers => true) do |row|
  #     jurisdiction = row['jurisdiction'].split.map(&:capitalize).join(' ')
  #     if !jurisdiction_to_zips.has_key?(jurisdiction)
  #       jurisdiction_to_zips[jurisdiction] = []
  #     end
  #     jurisdiction_to_zips[jurisdiction].push row['zip']
  #   end

  #   zips_count = 0
  #   prop_count = 0
  #   jurisdiction_to_proposals.each do |jurisdiction, proposals|
  #     jurisdiction = jurisdiction.split.map(&:capitalize).join(' ')
  #     zips = jurisdiction_to_zips[jurisdiction]
  #     if !jurisdiction_to_zips.has_key?(jurisdiction)
  #       errors.push "ERROR: jurisdiction #{jurisdiction} not found!...skipping"
  #       next
  #     end
  #     pp "For #{jurisdiction}, adding #{zips.length} zips to #{proposals.length} measures"
  #     zips_count += zips.length
  #     prop_count += proposals.length
  #     # tags = zips.map{|z|"zip:#{z}"}.join(';')

  #     proposals.each do |p|
  #       p.add_tag "type:local"
  #       p.add_tag "jurisdiction:#{jurisdiction}"
  #       p.add_seo_keyword jurisdiction

  #       zips.each do |zip|
  #         p.hide_on_homepage = true
  #         p.add_tag "zip:#{zip}"
  #       end
  #       p.save

  #     end
  #   end

  #   result = {
  #     :jurisdiction_errors => errors,
  #     :jurisdictions => "Processed #{jurisdiction_to_proposals.length} jurisdictions, adding #{zips_count} zip codes across #{prop_count} measures"
  #   }
  #   result


  # end


  private

  def access
    return current_user.super_admin
  end


end