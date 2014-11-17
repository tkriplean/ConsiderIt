require 'digest/md5'

ENABLE_HOMEPAGE_IN_DEV = false

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token, if: :csrf_skippable?

  set_current_tenant_through_filter
  prepend_before_action :get_current_subdomain
  before_action :init_thread_globals

  def render(*args)
    if !current_subdomain
      super 
      return
    end

    if Rails.cache.read("avatar-digest-#{current_subdomain.id}").nil?
      Rails.cache.write("avatar-digest-#{current_subdomain.id}", 0)
    end

    if params.has_key?('u') && params.has_key?('t') && params['t'].length > 0
      user = User.find_by_lower_email(params[:u])

      # for testing private discussions
      # pp ApplicationController.arbitrary_token("#{user.email}#{user.unique_token}#{current_subdomain.name}") if !user.nil?
      # pp ApplicationController.arbitrary_token("#{params[:u]}#{current_subdomain.name}") if user.nil?


      # is it a security problem to allow users to continue to sign in through the tokenized email after they've created an account?
      permission =   (ApplicationController.arbitrary_token("#{params[:u]}#{current_subdomain.name}") == params[:t]) \
                  ||(!user.nil? && ApplicationController.arbitrary_token("#{params[:u]}#{user.unique_token}#{current_subdomain.name}") == params[:t]) # this user already exists, want to have a harder auth method; still not secure if user forwards their email

      if permission
        session[:limited_user] = user ? user.id : nil
        @limited_user_follows = user ? user.follows.to_a : []
        @limited_user = user
        @limited_user_email = params[:u]
      end
    elsif session.has_key?(:limited_user ) && !session[:limited_user].nil?
      @limited_user = User.find(session[:limited_user])
      @limited_user_follows = @limited_user.follows.to_a
      @limited_user_email = @limited_user.email
    end


    if current_subdomain.host.nil?
      current_subdomain.host = request.host
      current_subdomain.host_with_port = request.host_with_port
      current_subdomain.save
    end

    # if there are dirtied keys, we'll append the corresponding data to the response
    if Thread.current[:dirtied_keys].keys.length > 0
      for arg in args
        if arg.is_a?(::Hash) && arg.has_key?(:json)
          if arg[:json].is_a?(::Hash)
            # This constraint is not principled, just how it works right now
            raise "JSON response must be an array if there are dirty objects"
          else 
            arg[:json] += compile_dirty_objects()
          end
        end
      end
    end

    super

  end

  def current_ability
    @current_ability ||= Ability.new(current_user, current_subdomain, request.session_options[:id], session, params)
  end

  def mail_options
    {:host => request.host,
     :host_with_port => request.host_with_port,
     :from => current_subdomain && current_subdomain.notifications_sender_email && current_subdomain.notifications_sender_email.length > 0 ? current_subdomain.notifications_sender_email : APP_CONFIG[:email],
     :app_title => current_subdomain ? current_subdomain.app_title : '',
     :current_subdomain => current_subdomain
    }
  end

  def self.token_for_action(user_id, object, action)
    user = User.find(user_id.to_i)
    Digest::MD5.hexdigest("#{user.unique_token}#{object.id}#{object.class.name}#{action}")
  end

  def self.arbitrary_token(key)
    Digest::MD5.hexdigest(key)
  end

protected
  def csrf_skippable?
    request.format.json? && request.content_type != "text/plain" && (!!request.xml_http_request?)
  end

  def write_to_log(options)
    begin
      Log.create!({
        :subdomain_id => current_subdomain.id,
        :who => current_user,
        :what => options[:what],
        :where => options[:where],
        :when => Time.current,
        :details => options.has_key?(:details) ? JSON.dump(options[:details]) : nil
      })
    rescue => e
      ExceptionNotifier.notify_exception(e)      
    end
  end

  def get_current_subdomain
    rq = request

    # when to display a considerit homepage
    can_display_homepage = (Rails.env.production? && rq.host.include?('consider.it')) || ENABLE_HOMEPAGE_IN_DEV
    if (rq.subdomain.nil? || rq.subdomain.length == 0) && can_display_homepage 
      set_current_tenant Subdomain.find_by_name('homepage')
      return current_subdomain
    end

    if rq.subdomain == 'googleoauth'
      candidate_subdomain = Subdomain.find_by_name(params['state'])
    else
      default_subdomain = session.has_key?(:default_subdomain) ? session[:default_subdomain] : 1
      candidate_subdomain = rq.subdomain.nil? || rq.subdomain.length == 0 ? Subdomain.find(default_subdomain) : Subdomain.find_by_name(rq.subdomain)
    end

    set_current_tenant(candidate_subdomain) if candidate_subdomain
    candidate_subdomain
  end

  def init_thread_globals
    # Make things to remember changes
    Thread.current[:dirtied_keys] = {}
    Thread.current[:subdomain] = current_subdomain
    Thread.current[:mail_options] = mail_options

    puts("In before: is there a current user? '#{session[:current_user_id2]}'")
    # First, reset the thread's current_user values from the session
    Thread.current[:current_user_id2] = session[:current_user_id2]
    Thread.current[:current_user2] = nil
    # Now let's see if they work
    if !current_user()
      # If not, let's make a new one, which will replace the old
      # values in the session and thread
      puts("That current_user '#{session[:current_user_id2]}' is bad. Making a new one.")
      new_current_user
    end

    # Remap crap:
    # Thread.current[:remapped_keys] = {}
    # # Remember remapped keys (but it turns out this doesn't work,
    # # cause session dies on sign_out!)
    # puts("Session remapped keys is #{session[:remapped_keys]}")
    # session[:remapped_keys] ||= {}
  end
  
  def new_current_user
    user = User.new
    if user.save
      puts("Signing into the stubby.  Curr=#{current_user}")
      set_current_user(user)
      puts("Signed into stubby.  Curr=#{current_user}")
    else
      raise 'Error making stub account. Yikes!'
    end
    user
  end

  def set_current_user(user)
    ## TODO: delete the existing current user if there's nothing
    ## important in it

    puts("Setting current user to #{user.id}")
    session[:current_user_id2] = user.id
    Thread.current[:current_user_id2] = user.id
    Thread.current[:current_user2]    = user
  end

  def compile_dirty_objects
    # Right now this works for points, opinions, proposals, and the
    # current opinion's proposal if the current opinion is dirty.

    response = []

    # Include the user object too, if we haven't already when fetching /current_user
    if Thread.current[:dirtied_keys].has_key?('/current_user') && !Thread.current[:dirtied_keys].has_key?("/user/#{current_user.id}")
      dirty_key "/user/#{current_user.id}"
    end

    dirtied_keys = Thread.current[:dirtied_keys].keys
    for key in Thread.current[:dirtied_keys].keys

      # Grab dirtied points, opinions, and users
      for type in [Point, Opinion, User, Comment, Moderation]
        if key.match "/#{type.name.downcase}/"
          response.append type.find(key_id(key)).as_json
          next
        end
      end

      if key.match "/proposal/"
        id = key[10..key.length]
        proposal = Proposal.find_by_id(id) || Proposal.find_by_slug(id)
        response.append proposal.as_json  #proposal_data

      elsif key.match "/comments/"
        point = Point.find(key[10..key.length])
        response.append Comment.comments_for_point(point)
      
      elsif key == '/subdomain'
        pp current_subdomain.notifications_sender_email
        response.append current_subdomain.as_json

      elsif key == '/current_user'
        response.append current_user.current_user_hash(form_authenticity_token)

      elsif key == '/proposals'
        response.append Proposal.summaries

      elsif key == '/users'
        response.append User.all_for_subdomain

      elsif key.match '/page/homepage'
        recent_contributors = ActiveRecord::Base.connection.select( "SELECT DISTINCT(u.id) FROM users as u, opinions WHERE opinions.subdomain_id=#{current_subdomain.id} AND opinions.published=1 AND opinions.user_id = u.id AND opinions.created_at > '#{9.months.ago.to_date}'")      

        clean = {
          contributors: recent_contributors.map {|u| "/user/#{u['id']}"},
          your_opinions: current_user.opinions.map {|o| o.as_json},
          key: key
        } 
        response.append clean

      elsif key.match "/page/"
        # default to proposal 
        slug = key[6..key.length]
        proposal = Proposal.find_by_slug slug

        pointz = proposal.points.where("((published=1 AND (moderation_status IS NULL OR moderation_status=1)) OR user_id=#{current_user ? current_user.id : -10})")
        pointz = pointz.public_fields.map {|p| p.as_json}

        published_opinions = proposal.opinions.published
        ops = published_opinions.public_fields.map {|x| x.as_json}

        if published_opinions.where(:user_id => nil).count > 0
          throw "We have published opinions without a user: #{published_opinions.map {|o| o.id}}"
        end


        clean = { 
          your_opinions: current_user.opinions.map {|o| o.as_json},
          key: key,
          proposal: proposal.as_json,
          points: pointz,
          opinions: ops
        }

        if current_subdomain.assessment_enabled
          clean.update({
            :assessments => proposal.assessments.completed,
            :claims => proposal.assessments.completed.map {|a| a.claims}.compact.flatten,
            :verdicts => Assessable::Verdict.all
          })
        end

        response.append clean
      elsif key.match '/assessment/'
        assessment = Assessable::Assessment.find(key[12..key.length])
        response.append assessment.as_json
      elsif key.match '/claim/'
        claim = Assessable::Claim.find(key[7..key.length])
        response.append claim.as_json
      end
    end

    return response
  end

  def store_location(path)
    session[:return_to] = path
  end

  #####
  # aliasing current_tenant from acts_as_tenant gem so we can be consistent with subdomain
  helper_method :current_subdomain
  def current_subdomain
    ActsAsTenant.current_tenant
  end

end
