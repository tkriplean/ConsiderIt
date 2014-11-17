class SubdomainController < ApplicationController
  respond_to :json

  rescue_from CanCan::AccessDenied do |exception|
    result = {
      :errors => [current_user.nil? ? 'not logged in' : 'not authorized']
    }
    render :json => result 
    return
  end

  def new
    render :json => []
  end

  def create
    authorize! :create, Subdomain

    errors = []

    # TODO: sanitize / make sure has url-able characters
    subdomain = params[:subdomain]

    existing = Subdomain.find_by_name(subdomain)
    if existing
      errors.push "The #{subdomain} subdomain already exists. Contact us for more information."
    else
      new_subdomain = Subdomain.new :name => subdomain
      roles = new_subdomain.user_roles
      roles['admin'].push "/user/#{current_user.id}"
      new_subdomain.roles = JSON.dump roles
      new_subdomain.save
    end

    if errors.length > 0
      render :json => [{errors: errors}]
    else
      render :json => [{name: new_subdomain.name}]
    end
  end

  def show
    dirty_key '/subdomain'
    render :json => []
  end

  def update
    subdomain = Subdomain.find(params[:id])
    authorize! :update, Subdomain
    if subdomain.id != current_subdomain.id #&& !current_user.super_admin
      # for now, don't allow modifying non-current subdomain
      raise new CanCan::AccessDenied
    end

    fields = ['moderate_points_mode', 'moderate_comments_mode', 'moderate_proposals_mode', 'about_page_url', 'notifications_sender_email', 'app_title', 'external_project_url', 'has_civility_pledge']
    attrs = params.select{|k,v| fields.include? k}

    if params.has_key? 'roles'
      attrs['roles'] = JSON.dump params['roles']
    end

    current_subdomain.update_attributes! attrs

    dirty_key '/subdomain'
    render :json => []

  end

end