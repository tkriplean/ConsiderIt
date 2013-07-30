
class Users::RegistrationsController < Devise::RegistrationsController

	protect_from_forgery
  skip_before_filter :verify_authenticity_token, :if => :file_uploaded

  def file_uploaded
    params[:remotipart_submitted].present? && params[:remotipart_submitted] == "true"
  end

  def create

    by_third_party = session.has_key? :access_token

    user = by_third_party ? User.find_by_third_party_token(session[:access_token]) : User.find_by_email(params[:user][:email])

    if user && user.registration_complete && (by_third_party || user.valid_password?(params[:user][:password]) )
      sign_in(resource_name, user)

      response = { 
        :result => 'logged_in',
        :reason => 'email_password_success'
      }

    elsif user

      response = {
        :result => 'rejected',
        :reason => 'user_exists'
      }

    elsif by_third_party
      user_params = User.create_from_third_party_token(session[:access_token]).update params[:user]
      
      user = User.new user_params #build_resource user_params
      user.referer = session[:referer] if session.has_key?(:referer)

      user.skip_confirmation! 

      is_dirty = user.avatar_url_provided?


      if user.save
        sign_in(resource_name, user)

        current_user.track!

        response = {
          :result => 'successful',
          #TODO: filter users' to_json?
          :user => current_user,
          :follows => current_user.follows.all, 
          :new_csrf => form_authenticity_token
        }

        session.delete(:access_token)
        if is_dirty
          dirty_avatar_cache     
        end

      end


    else #registration via email
      user = build_resource
      user.referer = session[:referer] if session.has_key?(:referer)
      if user.save
        sign_in(resource_name, user)
        current_user.track!

        if params[:user].has_key? :avatar
          dirty_avatar_cache     
        end

        # set_flash_message :notice, :signed_up

        response = {
          :result => 'successful',
          #TODO: filter users' to_json
          :user => current_user,
          :follows => current_user.follows.all, 
          :new_csrf => form_authenticity_token
        }

      else
        response = {
          :result => 'rejected',
          :reason => 'validation error'
        }

      end 
    end
    render :json => response

  end

  def update
    # not using skip confirmation because it sets confirmed_at on additional info provisioning...not sure why it was enabled
    #current_user.skip_confirmation!

    # TODO: explicitly grab params

    if current_user.update_attributes(params[:user])

      results = {
        :result => 'successful',
        #TODO: filter users' to_json
        :user => current_user
      }

      if params[:user].has_key? :avatar
        dirty_avatar_cache   
      end

      #sign_in @user, :bypass => true if params[:user].has_key?(:password)
      render :json => results
    else 
      render :json => {
        :result => 'failed',
        :reason => 'could not save user'
      }
    end

    #current_user.skip_confirmation!
    #current_user.save

    #if params[:user].has_key?(:proposal_id)
    #  # this is for caching purposes, particularly the histogram
    #  Proposal.find_by_id(params[:user].delete(:proposal_id)).touch
    #end
    #redirect_to !request.referer.nil? ? request.referer : root_path

  end

  def destroy
    resource.destroy
    Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
    render :json => { :result => 'successful', :new_csrf => form_authenticity_token }
  end


  # DEPRECATED
  #def check_login_info    
  #  email = params[:user][:email]
  #  password = params[:user][:password]

  #  user = User.find_by_email(email)
  #  email_in_use = !user.nil?

  #  render :json => { :valid => !email_in_use || user.valid_password?(password) }
  #end

protected
  def dirty_avatar_cache
    current = Rails.cache.read("avatar-digest-#{current_tenant.id}")
    Rails.cache.write("avatar-digest-#{current_tenant.id}", current + 1)   
  end
end