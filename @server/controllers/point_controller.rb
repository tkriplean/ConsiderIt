class PointController < ApplicationController
  protect_from_forgery

  def show
    point = Point.find params[:id]
    authorize! :read, point

    ApplicationController.reset_user_activities(session, point.proposal) if !session.has_key?(point.proposal.id)

    render :json => point.as_json
  end


  def create
    # Validate by filtering out unwanted fields
    # todo: validate data types too
    fields = [:nutshell, :text, :is_pro, :hide_name, :proposal]
    point = params[:point].select{|k,v| fields.include? k}

    # Set private values
    proposal = Proposal.find(point.proposal)
    point[:comment_count] = 0
    point[:long_id] = proposal.long_id
    point[:user_id] = current_user ? current_user.id : nil,
    point[:published] = false
    
    point = Point.new ActionController::Parameters.new(point).permit!

    #TODO: look into cancan to figure out how we can move this earlier in the method
    authorize! :create, point

    point.save

    ApplicationController.reset_user_activities(session, proposal) if !session.has_key?(proposal.id)

    session[proposal.id][:written_points].push(point.id)
    session[proposal.id][:included_points][point.id] = 1    
    session[proposal.id][:viewed_points].push([point.id, 7]) # own point has been seen
    
    render :json => point
  end

  def update
    point = Point.find params[:id]
    #authorize! :update, point

    fields = ["nutshell", "text", "hide_name"]
    updates = params.select{|k,v| fields.include? k}

    point.update_attributes! ActionController::Parameters.new(updates).permit!

    if point.published
      ActiveSupport::Notifications.instrument("point:updated", 
        :model => point,
        :current_tenant => current_tenant,
        :mail_options => mail_options
      )
    end

    render :json => point.as_json
  end

  def destroy
    return unless request.xhr?

    @point = Point.find params[:id]
    
    authorize! :destroy, @point

    ApplicationController.reset_user_activities(session, @point.proposal) if !session.has_key?(@point.proposal.id)
    
    session[@point.proposal_id][:written_points].delete(@point.id)
    session[@point.proposal_id][:included_points].delete(@point.id)  
    session[@point.proposal_id][:viewed_points].delete(@point.id)

    # if this point is a top pro or con, need to trigger proposal update
    proposal = @point.proposal
    update_proposal_metrics = proposal.top_pro == @point.id || proposal.top_con == @point.id      
    update_opinion = current_user && opinion = current_user.opinions.find_by_proposal_id(point.proposal_id)

    @point.destroy

    opinion.update_inclusions if update_opinion
    proposal.update_metrics if update_proposal_metrics

    response = {:result => 'successful'}

    respond_to do |format|
      format.json {render :json => response}
    end

  end

  
  
end
