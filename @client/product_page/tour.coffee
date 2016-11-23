require './testimonials'


window.Demo = (props) -> 
  loc = fetch('location')
  
  watch_demo = -> 
    window.scrollTo(0,0)    
    loc.query_params.play_demo = true 
    save loc 

  DIV 
    style:
      position: 'relative'
      width: props.width
      height: props.height
      margin: 'auto'
      cursor: 'pointer'

    onClick: watch_demo
    onKeyPress: (e) -> 
      if e.which == 13 || e.which == 32 # ENTER or SPACE
        e.preventDefault()
        watch_demo()

    BUTTON 
      style: _.extend {}, big_button(), 
        position: 'absolute'
        top: props.height / 2
        left: props.width / 2 - 249 / 2
        padding: '0px 30px 5px 50px'
        fontSize: 14
        display: if loc.query_params.play_demo then 'none'

      SPAN 
        style: 
          verticalAlign: 'middle'
          paddingRight: 20
          display: 'inline-block'
          textAlign: 'left'
          paddingTop: 10

        SPAN 
          style: 
            lineHeight: '14px'
            fontSize: 16
            paddingTop: 5
          'Watch the Demo'
        BR null 
        SPAN 
          style: 
            fontSize: 10
            fontWeight: 500
            position: 'relative'
            top: -3
          'It is silent. Library friendly!'

      SVG 
        style: 
          verticalAlign: 'middle'

        height: 25
        width: 25
        viewBox: "0 0 200 200"


        PATH 
          d: "M5 5 L5 195 L195 95 Z"  
          fill: "#ffffff" 

    
    Webframe 
      browser_loc: 'https://galacticfederation.consider.it/Death_Star'
      width: props.width

      DIV 
        style: 
          width: '90%'
          margin: 'auto'
        DIV 
          style: 
            fontSize: 36
            fontWeight: 500
            margin: '30px 0 0px 0'
            textAlign: 'center'

          'Admit the Death Star into the Republic?'

        IMG 
          src: asset 'product_page/death_star_example.png'
          style:
            width: '80%'

    # IMG 
    #   src: asset('product_page/tour_demo_death_star.png')
    #   style: 
    #     width: props.width
    #     height: props.height
    #     borderRadius: '4px 4px 0 0'
    #     backgroundColor: 'white'


window.Tour = ReactiveComponent
  displayName: 'Tour'

  render: -> 

    compact = browser.is_mobile || SAAS_PAGE_WIDTH() < 700

    DIV null,

      DIV 
        style: 
          textAlign: 'center'
          paddingTop: 48        
          position: 'relative'
          top: 8

        Demo 
          width: Math.min 800, .8 * SAAS_PAGE_WIDTH()
          height: Math.min 453, .8 * SAAS_PAGE_WIDTH() * 453 / 800

      DIV 
        style: 
          position: 'relative'
          zIndex: 2
          backgroundColor: 'white'
          boxShadow: '0px -17px 27px 0px rgba(0,0,0,.14)'
          paddingTop: 30
          paddingBottom: 70

        DIV 
          style: 
            maxWidth: 765 + 90 
            margin: 'auto'
            padding: '0px 40px'

          H1 
            style: _.extend {}, h1,
              color: '#303030'  
              textAlign: 'center'  
              fontSize: if SAAS_PAGE_WIDTH() < 800 then 34 else 42            

              # fontSize: if compact then 36 else 50
              # fontWeight: 800
              # color: 'white'
              # paddingBottom: 40
              # textShadow: '0px 2px 4px rgba(0,0,0,.2)'

            "The only forum to visually summarize what your community thinks and why"


        DIV 
          style: 
            marginTop: 20
          TestimonialGrid 
            testimonials: [testimonials.pierre, testimonials.auryn]
            maxWidth: 900
            top: false 
            italic: true

        # DIV 
        #   style: 
        #     margin: 'auto'
        #     maxWidth: 1000
        #     marginTop: 40
        #     padding: '0px 40px'
        #     display: css.crossbrowserify 'flex'


        #   DIV 
        #     style: css.crossbrowserify
        #       display: 'inline-block'
        #       width: if !compact then '45%'
        #       margin: '0 20px'
        #       verticalAlign: 'top'
        #       flex: '1 1 auto'

        #     Testimonial 
        #       testimonial: testimonials.pierre 
        #       left: true 

        #   if !compact 
        #     DIV 
        #       style: css.crossbrowserify
        #         display: 'inline-block'
        #         width: '45%'
        #         margin: '0 20px'
        #         flex: '1 1 auto'

        #       Testimonial
        #         testimonial: testimonials.auryn
        #         left: false 
        #         verticalAlign: 'top'
        

        Features()
        Research()   

  reevaluateActiveFeature: -> 
    f = fetch 'active_feature'

    features = $('.feature')
    yoff = window.pageYOffset

    active = null
    top_most = Infinity
    found_perfect = false 
    most_in_view = 0 

    for feature in features 
      coords = getCoords(feature)

      viewport_top = document.documentElement.scrollTop or document.body.scrollTop
      viewport_bottom = viewport_top + (document.documentElement.clientHeight or window.innerHeight)
      
      above_viewport = coords.top + 60 < viewport_top
      below_viewport = coords.bottom > viewport_bottom

      # prioritize any feature that is entirely visible
      # ...but fall back to the feature with the greatest # of pixels visible

      is_perfect = !above_viewport && !below_viewport
      if is_perfect
        if !found_perfect || top_most > coords.top 
          found_perfect = true 
          active = feature
          top_most = coords.top 
      else if !found_perfect
        amount_in_viewport = Math.min(coords.bottom, viewport_bottom) - Math.max(coords.top, viewport_top)
        if amount_in_viewport > most_in_view && amount_in_viewport > 125
          active = feature 


    if !active && f.active 
      f.active = null
      save f 
    else if active 
      id = active.getAttribute('data-id') 

      if id != f.active 
        f.active = id 
        loc = fetch 'location'
        loc.hash = id
        save f 
        save loc

  componentDidMount: -> 
    scrolled = false
    $(window).on "scroll.feature_tracker", -> scrolled = true
    @reevaluateActiveFeature()
    @int = setInterval => 
      if scrolled 
        scrolled = false 
        @reevaluateActiveFeature()
    , 100

  componentWillUnmount: -> 
    clearInterval @int
    $(window).off "scroll.feature_tracker"


Features = -> 
  feature_sections = [
    {
      label: "Explore Consider.it's features"
      features: basic_features
      footer: -> 
        DIV 
          style: 
            textAlign: 'center'
            marginTop: 40

          A
            href: '/create_forum'
            style: big_button()

            'Start a free forum'

          DIV 
            style: 
              color: '#676767'
              fontSize: 14
              marginTop: 6


            'you can upgrade later if you wish'

    }
    {
      label: "Additional functionality for paid forums"
      features: paid_features
      footer: -> 
        DIV 
          style: 
            textAlign: 'center'
            paddingTop: 40

          A 
            href: '/pricing'
            style: 
              textDecoration: 'underline'
              color: primary_color()
              fontSize: 24
              fontWeight: 700
            'Learn more about our paid plans'

    }
  ]
  
  compact = browser.is_mobile || SAAS_PAGE_WIDTH() < 800

  DIV 
    id: 'features_tour'
    style: 
      paddingTop: 60

    A name: 'features'




    for section, idx in feature_sections
      DIV 
        style: 
          paddingBottom: 80
          paddingTop: 20

        if section.label 
          H2
            style: 
              color: primary_color()
              fontSize: 42
              margin: '20px 0 20px 0'
              textAlign: 'center'
              fontWeight: 400
            section.label 

        # feature menu
        if false && !compact && idx == 0

          FeatureMenu {feature_sections}

        UL 
          style: 
            listStyle: 'none'

          for feature, idx in section.features
            

            Feature 
              key: feature.label
              feature: feature 
              sections: feature_sections
              is_last: idx == section.features.length - 1

        section.footer?()


FeatureMenu = ReactiveComponent
  displayName: 'FeatureMenu'

  render: -> 
    feature_sections = @props.feature_sections
    active_feature = fetch('active_feature').active

    DIV 
      style: 
        position: 'fixed'
        left: 10
        top: 150
        zIndex: 3
        display: if !active_feature then 'none'

      for section, idx in feature_sections

        UL 
          style: 
            listStyle: 'none'

          for f in section.features
            is_active = active_feature == f.id
            LI null,
              A 
                'data-nojax': true
                href: "##{f.id}"                
                style: 
                  color: if is_active then primary_color() else '#000'
                  fontSize: 14
                  fontWeight: 500
                  opacity: if !is_active then .5
                capitalize f.id.replace(/_/g, ' ')
                if idx == 1
                  SPAN 
                    style: 
                      color: '#7ED321'
                      paddingLeft: 4
                    '$'



Feature = ReactiveComponent
  displayName: 'Feature'

  render: -> 
    feature = @props.feature

    active = fetch('active_feature').active == feature.id

    has_media = !!feature.img || !!feature.video || !!feature.testimonial

    LI 
      className: 'feature'
      'data-id': feature.id    
      style: 
        padding: 40
        position: 'relative'
        backgroundColor: if active then '#f9f9f9' else 'white'
        transition: 'background-color 500ms, border-color 500ms'
        zIndex: if active then 2 else 1

      A name: feature.id


      DIV 
        style: 
          maxWidth: 800
          margin: 'auto'


        DIV 
          style: 
            width: '80%'
            verticalAlign: 'top'
            margin: 'auto'

          if feature.label 
            H3
              style: 
                fontSize: 32
                fontWeight: 700
                marginBottom: 16
                textAlign: 'center'
                #color: if active then primary_color()
              feature.label


        if has_media
          boxShadow = if !feature.testimonial
                        if active 
                          '0 1px 4px rgba(0,0,0,.25)' 
                        else 
                          '0 1px 4px rgba(0,0,0,.1)'
                      else 
                        null
          DIV 
            style:
              width: '80%'
              verticalAlign: 'top'
              lineHeight: 0
              margin: '0px auto 20px auto'

            if feature.img 
              is_gif = feature.img.indexOf('.gif') > -1
              sty = 
                width: '100%'
                backgroundColor: 'white'
                #opacity: if !active && is_gif then .2
                transition: if is_gif then 'opacity 500ms'
                boxShadow: boxShadow
                transition: 'box-shadow 500ms'

              # if is_gif && !active
              #   sty = css.grayscale sty 

              IMG 
                src: feature.img 
                style: sty

            else if feature.video

              VIDEO
                ref: 'video'
                preload: true
                loop: true
                autoPlay: true
                controls: false
                style: 
                  position: 'relative'
                  width: Math.min(SAAS_PAGE_WIDTH() - 80, 800, @local.video_height * 1920/1080)
                  height: Math.min(1080/1920 * (SAAS_PAGE_WIDTH() - 80), 800 * 1080/1920, @local.video_height or 0)
                  boxShadow: boxShadow
                  transition: 'box-shadow 500ms'


                for format in ['mp4', 'webm']
                  asset_path = asset("product_page/#{feature.video}.#{format}")
                  if asset_path?.length > 0
                    SOURCE
                      key: format
                      src: asset_path
                      type: "video/#{format}"

                "Your browser does not support the video element."
            else if feature.testimonial
              DIV 
                style: 
                  marginTop: 0

                # Testimonial
                #   testimonial: feature.testimonial
                #   bubble_color: "#eee"

                # DIV 
                #   style: 
                #     fontWeight: 200
                #     fontSize: 20
                #     fontStyle: 'italic'
                #   feature.testimonial.text 

                # DIV 
                #   style: 
                #     textAlign: 'right'
                #     color: '#303030'
                #     fontSize: 18
                #     marginTop: 16

                #   feature.testimonial.author

        DIV 
          style: 
            width: '80%'
            verticalAlign: 'top'
            margin: 'auto'

          if feature.html 
            DIV 
              style: 
                fontSize: 18
                color: '#303030'
              dangerouslySetInnerHTML: {__html: feature.html}


  updateVideoPlayStatus: -> 
    if @refs.video 
      active = fetch('active_feature').active == @props.feature.id
      el = @refs.video?.getDOMNode()
      if el 
        try 
          if active
            #@refs.video.getDOMNode().load()
            el.currentTime = 0
            el.play?()
          else 
            el.pause?()
        catch e 
          console.error e


  componentDidMount: -> 
    @updateVideoPlayStatus()
    if @refs.video && !@local.video_height?
      @local.video_height = @refs.video.getDOMNode().parentNode.offsetWidth * 1080/1920

  componentDidUpdate: -> 
    @updateVideoPlayStatus()


basic_features = [
 {
  id: 'opinion_slate'    
  label: 'An Opinion Slate for your community'
  html: 'Consider.it organizes the issues confronting your community. Request feedback on proposals, plans, policies, programs and designs. Or go a step further and empower individuals to contribute their own ideas. Consider.it makes everyone’s opinion on each proposal visible so it is easier to get on the same page.'
  video: 'opinion_slate'  
 }
 {
  id: 'proposals'    
  label: 'Each proposal can be developed in detail'
  html: 'Add as much detail to proposals as you wish, including embedding images or video. You control whether your community can post their own proposals.'
  video: 'proposal_development'
 }
 {
  id: 'slide_opinions'    
  label: 'See your opinion in relation to others'
  html: 'Individuals slide their overall opinion about a proposal, integrating their opinion with others. The slider endpoints are configurable. You can set them to Agree/Disagree, High Priority/Low Priority or whatever your community is evaluating about a proposal.'
  video: 'slide_it'   
 }
 {
  id: 'pro_con_dialogue'    
  label: 'Dialogue to surface the pros and cons'
  html: 'Individuals express what they see as the most important tradeoffs, pro and con. While doing so, individuals have access to the pros and cons others have already contributed. Your community members learn from each other as they use Consider.it, and from you.'
  video: 'pro_con'
 }
 {
  id: 'explore_opinions'    
  label: 'Gain deeper understanding by exploring patterns of thought'
  html: 'Consider.it provides a dynamically updating, interactive summary of what your community thinks and why. You can drill deeper into the underlying reasons for different groups. For example, learn the reservations of those who are opposing a proposal — perhaps 80% of those with reservations share two Con points that can be addressed!'
  video: 'explore'
 }
 {
  id: 'encourage_civility'    
  label: 'Set focus and encourage civility'
  html: 'Consider.it helps participants focus on the pro/con tradeoffs, rather than each other. Personal attacks don’t make sense in the format. Individuals can engage in long discussions about single points, but they’re contained and don’t hijack the overall conversation.'
  video: 'drilldown'
 } 

 {
  id: 'accessibility'  
  label: 'Accessible for the disabled'
  html: 'Consider.it is <a href="https://www.w3.org/WAI/intro/wcag.php" target="_blank" style="text-decoration: underline;">WCAG</a> Level A compliant. Consider.it also provides a mechanism for users of screenreaders to ask for help. We help each of these folks individually to understand the proposals being discussed and input their opinions.'
  testimonial: testimonials.sheri 
 }

 {
  id: 'private_forums'    
  label: 'Private Forums'
  html: 'By default, anyone with a link can access a Consider.it forum. With Private Forums, you can lock down your forum to only those you invite via email. You can also make specific proposals private even if the rest of the forum is public.'
 }

]



paid_features = [
 {
  id: 'customization'
  label: 'Customized Look, Feel, and Functionality'
  html: 'We can work with you to design and implement a forum with the look and feel that you want for your brand. Moreover, we have a number of homepage templates that we can enable that can add additional organization to your community’s issues.'
  img: asset('product_page/customize_homepage.gif')
 }

 {
  id: 'profile_questions'  
  label: 'Ask demographic and profile questions'
  html: 'Optionally ask for additional information when someone creates an account on your forum. For example, you can ask if they are a Donating Member of your organization. Or you can ask if they are a homeowner. Or you can ask demographic questions like age and race. This information is available in data exports. It can also be used in our opinion analytics described below.'
  video: 'profile_questions'
 }

 {
  id: 'opinion_analytics'    
  label: 'Opinion Analytics for survey-like cross-tabs'
  html: 'You may wish to filter opinions based upon user characteristics or some other differentiator. For example, you might want to learn what Board Members think of a proposal. Or perhaps you want to learn what renters think of a planning proposal, filtering out homeowners. We can help you surface the information you need.'
  video: 'analytics'
 }

 {
  id: 'translation'    
  label: 'Multilingual forums & Google Translate'
  html: 'We offer interface translations in a number of languages, and can do translations to other languages with help. Furthermore, for multi-lingual websites, we offer Google Translate integration.'
  img: asset('product_page/translation.gif')
 }
 {
  id: 'moderation'    
  label: 'Content Moderation'
  html: 'You can choose to review content before it is publicly posted, or just enable moderation for review after posting. The moderation interface enables you to directly contact the author if you wish to ask them to revise a statement that violates community standards. Note that moderation is rarely burdonsome – even for contentious issues, Consider.it tends to foster civil interactions.'
  #img: asset('product_page/moderation.png')
 }
 {
  id: 'data_export'    
  label: 'Data export'
  html: 'Export your forum data into CSV format. We can work with you if you have other data requirements.'
  img: ''
 }
 {
  id: 'traffic_analytics'    
  label: 'Google Analytics integration'
  html: 'Add Google Analytics to your forum to understand your forum’s traffic.'
  img: ''
 } 

]  




Research = -> 

  # | 323666 | Travis Kriplean, PhD, Computer Science, University of Washington                |
  # | 324669 | Deen Freelon, Assistant Professor of Communication Studies, American University |
  # | 324670 | Alan Borning, Professor of Computer Science, University of Washington           |
  # | 324671 | Lance Bennett, Professor of Political Science, University of Washington         |
  # | 324672 | Jonathan Morgan, PhD, Human Centered Design, University of Washington           |
  # | 324673 | Caitlin Bonnar, Computer Science, University of Washington                      |
  # | 324674 | Brian Gill, Professor of Statistics, Seattle Pacific University                 |
  # | 324675 | Bo Kinney, Librarian, Seattle Public Library                                    |
  # | 324678 | Menno De Jong, Professor of Behavioral Sciences, University of Twente           |
  # | 324679 | Hans Stiegler, Behavioral Sciences, University of Twente                        |

  authors = (author_list) -> 
    DIV 
      style:
        position: 'absolute'
        top: 5
        right: -40


      UL 
        style:
          display: 'inline'

        for author,idx in author_list
          LI 
            key: idx
            style: 
              display: 'inline-block'
              listStyle: 'none'
              zIndex: 10 - idx
              position: 'absolute'
              left: 25 * idx
              top: 25 * idx

            Avatar
              key: "/user/#{author}"
              user: "/user/#{author}"
              img_size: 'large'
              style: 
                width: 50
                height: 50


  papers = [
    {
      url: "http://dub.washington.edu/djangosite/media/papers/kriplean-cscw2012.pdf"
      title: 'Supporting Reflective Public Thought with Consider.it'
      venue: '2012 ACM Conference on Computer Supported Cooperative Work'
      authors: [323666, 324672, 324669, 324670, 324671]
    },    {
      url: "https://dl.dropboxusercontent.com/u/3403211/papers/jitp.pdf"
      title: 'Facilitating Diverse Political Engagement'
      venue: 'Journal of Information Technology & Politics, Volume 9, Issue 3'
      authors: [324669, 323666, 324672, 324671, 324670]
    },    {
      url: "http://homes.cs.washington.edu/~borning/papers/kriplean-cscw2014.pdf"
      title: 'On-demand Fact-checking in Public Dialogue'
      venue: '2014 ACM Conference on Computer Supported Cooperative Work'
      authors: [324673, 323666, 324670, 324675, 324674]
    },    {
      url: "http://www.sciencedirect.com/science/article/pii/S0747563215003891"
      title: 'Facilitating Personal Deliberation Online: Immediate Effects of Two Consider.it Variations'
      venue: 'Computers in Human Behavior, Volume 51, Part A'
      authors: [324679, 324678]
    }
  ]

  w = Math.min SAAS_PAGE_WIDTH(), 680

  DIV 
    style: 
      width: SAAS_PAGE_WIDTH()
      margin: '40px auto'
    A name: 'research'

    H1
      style: _.extend {}, h1, 
        margin: '20px auto 40px auto'
        color: '303030'
        maxWidth: 750
        textAlign: 'center'
        fontWeight: 600

      'Peer-reviewed academic research about Consider.it'

    DIV 
      style: 
        fontSize: 18
        maxWidth: 800
        margin: 'auto'
        color: '#303030'
        marginBottom: 40

      """Consider.it was originally created at the University of Washington as part of the 
         National Science Foundation funded dissertation research of Founder Travis Kriplean, 
         in collaboration with colleagues in Computer Science & Engineering, Political 
         Communication, Statistics, and Human-centered Design & Engineering."""

    UL
      style: 
        listStyle: 'none'
        width: w
        position: 'relative'
        left: '50%'
        marginLeft: -w / 2 - 50

      for paper in papers
        LI 
          key: paper.title
          style: 
            padding: '16px 32px'
            position: 'relative'
            backgroundColor: considerit_gray
            boxShadow: '#b5b5b5 0 1px 1px 0px'
            borderRadius: 32
            marginBottom: 20

          A 
            style:  
              textDecoration: 'underline'
              color: primary_color()
              fontSize: 20
            href: paper.url
            paper.title
          DIV 
            style: _.extend {}, small_text
            paper.venue

          DIV
            style: css.crossbrowserify
              transform: 'rotate(90deg)'
              position: 'absolute'
              right: -27
              top: 20

            Bubblemouth 
              apex_xfrac: 0
              width: 30
              height: 30
              fill: considerit_gray
              stroke: 'transparent'
              stroke_width: 0
              box_shadow:   
                dx: 3
                dy: 0
                stdDeviation: 2
                opacity: .5


          authors paper.authors
