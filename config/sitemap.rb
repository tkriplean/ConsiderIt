SitemapGenerator::Sitemap.sitemaps_host = "http:consider.it"

Subdomain.find_each do |subdomain|

  indexability = APP_CONFIG[:indexability]
  indexed = indexability.has_key?(subdomain.name.intern) ? indexability[subdomain.name.intern] : indexability[:default]  
  next if !indexed

  subdomain = subdomain.name  
  # Set the host name for URL creation
  SitemapGenerator::Sitemap.default_host = "https://#{subdomain.host}"

  SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/#{subdomain}"

  SitemapGenerator::Sitemap.create do
    # Put links creation logic here.
    #
    # The root path '/' and sitemap index file are added automatically for you.
    # Links are added to the Sitemap in the order they are specified.
    #
    # Usage: add(path, options={})
    #        (default options are used if you don't specify)
    #
    # Defaults: :priority => 0.5, :changefreq => 'weekly',
    #           :lastmod => Time.now, :host => default_host
    #
    subdomain.proposals.active.open_to_public.each do |prop|
      begin
        add prop.slug, {:priority => 1.0, :changefreq => 'daily'}
      rescue
        pp "#{prop.slug} failed"
      end
    end

    subdomain.proposals.where( :active => false, :published => true ).open_to_public.each do |prop|
      next if prop.opinions.published.count == 0
      
      begin
        add prop.slug, {:priority => 0.2, :changefreq => 'monthly'}
        #add proposal_path(prop.slug), {:priority => 0.7, :changefreq => 'weekly'}
      rescue
        pp "#{prop.slug} failed"
      end
    end

    if subdomain.about_page_url
      add "about", {:priority => 0.8, :changefreq => 'monthly'}
    end

  end
  #SitemapGenerator::Sitemap.ping_search_engines

end