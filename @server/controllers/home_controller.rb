
#TODO: probably should rename this controller "HTMLController" or something, and move the avatar stuff elsewhere

class HomeController < ApplicationController

  caches_action :avatars, :cache_path => proc {|c|
    {:tag => "avatars-#{current_tenant.id}-#{Rails.cache.read("avatar-digest-#{current_tenant.id}")}-#{session[:search_bot]}"}
  }

  def index

    # if someone has accessed a non-existent subdomain
    if !current_tenant
      render :file => "#{Rails.root}/public/404.html", :layout => false, :status => :not_found
      return
    end

    if !session.has_key?(:search_bot)
      session[:search_bot] =    !!request.fullpath.match('_escaped_fragment_')  \
                             || !request.user_agent #\
                             #|| !!request.user_agent.match('Prerender') \
                             #|| !!request.user_agent.match(/\(.*https?:\/\/.*\)/) #http://stackoverflow.com/questions/5882264/ruby-on-rails-how-to-determine-if-a-request-was-made-by-a-robot-or-search-engin
      #session[:search_bot] = !!request.fullpath.match('_escaped_fragment_') || (request.user_agent && !!request.user_agent.match('Prerender'))
    end

    # Some customers don't have a homepage. In the iterim, let's just redirect 
    # accesses to the homepage to the latest published proposal
    # TODO: better way of knowing if a particular customer has a homepage or not.
    if current_tenant.identifier == 'cityoftigard' && request.path == '/' && request.query_string == "" && !session[:search_bot]
      proposal = current_tenant.proposals.open_to_public.active.last
      if proposal
        redirect_to "/#{proposal.long_id}"
      else
        render :file => "#{Rails.root}/public/404.html", :layout => false, :status => :not_found
      end
      return
    end

    response.headers["Strict Transport Security"] = 'max-age=0'
    
    # used by the layout
    @meta, @page, @title = get_meta_data()
    @is_search_bot = session[:search_bot]

    if !session[:search_bot]
      referer = params.has_key?('z') && params['z'] == '1' ? 'from email notification' : request.referer
      write_to_log({
        :what => 'landed on site',
        :where => request.fullpath,
        :details => {
          :referer => referer, 
          :ip => request.remote_ip, 
          :user_agent => request.env["HTTP_USER_AGENT"]
        }
      })
    end

    render "layouts/application", :layout => false
  end


  def activemike
    render "layouts/testmike", :layout => false
  end

  def avatars
    if session[:search_bot] # don't fetch avatars for search bots
      render :json => {}
    else 
      respond_to do |format|
        format.html { render :partial => './avatars' } 
        format.json { render :partial => './avatars' }
      end
    end
  end

  #### Set meta tag info ####
  # Hardcoded for now. 
  # TODO: store customer meta data in the database
  def get_meta_data

    page = request.path
    
    proposal = nil
    keywords = title = nil

    # customer defaults
    case current_tenant.identifier
    when 'livingvotersguide'
      title = 'Washington Voters Guide for the 2014 Election'
      image = view_context.image_url 'livingvotersguide/logo.png'
      description = "Washington's Citizen-powered Voters Guide. Decide for yourself about the issues on your 2014 ballot, with a little help from your neighbors."
      keywords = "voting,voters guide,online voters guide,2014,ballot,washington,washington state,election,pamphlet,voters pamphlet,ballot measures,citizen,initiatives,propositions,2014 elections,online voter pamphlet,voting facts,voters information,voting ballot 2014,voting information 2014,information about voting,election dates,electoral ballot,wa,seattle,tacoma,spokane,yakima,vancouver"
      fb_app_id = '159147864098005'
    when 'cityoftigard'
      title = "City of Tigard Dialogue"
      image = view_context.image_url 'cityoftigard/logo.png'
      description = "Dialogue about City of Tigard"
    else
      title = current_tenant.app_title or "#{current_tenant.identifier} discussion"
      image = nil
      description = "Help think through these issues being considered."
    end

    # proposal overrides, if the current page is a proposal
    proposal = Proposal.find_by_long_id page[1..page.length] if page != '/' && page != '/about'
    if proposal 
      title = proposal.name
      if proposal.category && proposal.designator
        title = "#{proposal.category[0]}-#{proposal.designator}: #{title}"
      end
      title = proposal.seo_title || title
      description = proposal.seo_description || "What do you think? #{proposal.description || proposal.name}"
      description = ActionView::Base.full_sanitizer.sanitize description
      keywords = proposal.seo_keywords if proposal.seo_keywords
    end

    meta = [
      { :name => 'title', :content => title },
      { :name => 'twitter:title', :content => title },
      { :property => 'og:title', :content => title },

      { :name => 'description', :content => description },
      { :name => 'twitter:description', :content => description },
      { :property => 'og:description', :content => description },

      { :name => 'keywords', :content => keywords },

      { :property => 'og:url', :content => request.original_url() },
      { :property => 'og:image', :content => image },

      { :property => 'og:type', :content => 'website' },
      { :property => 'og:site_name', :content => (current_tenant.app_title or "#{current_tenant.identifier} discussion") },

      { :name => 'twitter:card', :content => 'summary' },
      { :property => 'fb:app_id', :content => fb_app_id }

    ]

    return meta, page, title
  end

end
