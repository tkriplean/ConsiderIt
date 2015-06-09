require "../bubblemouth"

VIDEO_FILE = 'slowdeathstarcam'


chapters = [
  {time:  6.0, caption: "Pretend we're considering this proposal", menu: "Consider an issue"},
  {time:  5.0, caption: "Consider.it helps us analyze its tradeoffs", menu: "Analyze tradeoffs"},
  {time:  8.5, caption: "Each thought becomes a Pro or Con point", menu: "Analyze tradeoffs"},
  {time:  7.0, caption: "We can learn from our peers", menu: "Learn from peers"},
  {time:  4.0, caption: "...and even build from them!", menu: "Learn from peers"},
  
  {time: 11.0, caption: "Weigh the tradeoffs on a slider", menu: "Summarize an opinion"},
  {time:  4.5, caption: "Now let's share our opinion", menu: "Summarize an opinion"},
  {time:  4.5, caption: "Behold: what people think, and why!", menu: "See what the group thinks"},
  {time:  4.0, caption: "A histogram shows the spectrum of opinions", menu: "Spectrum of opinion"},
  {time:  4.0, caption: "Points are ranked by importance to the group", menu: "Top tradeoffs"},

  {time:  8.5, caption: "Now explore patterns of thought!", menu: "Explore patterns of thought"},
  {time:  6.0, caption: "Learn the reservations of opposers", menu: "Explore patterns of thought"},
  {time: 12.5, caption: "Inspect a peer's opinion", menu: "Inspect a peer’s opinion"},
  {time:  8.0, caption: "See who resonates with the top Pro", menu: "Inspect a peer’s opinion"},
  {time:  4.0, caption: "Focus on a single point", menu: "Focus & discuss a single point"},
  {time: 11.0, caption: "...and discuss its implications", menu: "Focus & discuss a single point"},
  {time:  0.0, caption: "Those are the basics! Learn more below", menu: "Focus & discuss a single point"},
]



DEMO_AUTOPLAY_DELAY = 5000

video_width = Math.min(SAAS_PAGE_WIDTH, window.innerWidth - 320)

caption_color =  "black" #logo_red focus_blue
current_chapter_color = logo_red #caption_color

window.Video = ReactiveComponent
  displayName: "video"
  render: ->

    DIV 
      id: 'demo'
      style: 
        width: video_width
        margin: "60px auto 0 auto"
        position: 'relative'

      @drawCaptions()
      @drawVideo()
      @drawChapterMenu()

      if @local.ready
        A
          href: 'https://fun.consider.it/Death_Star'
          target: '_blank'
          style: 
            cursor: 'pointer'
            color: focus_blue
            textDecoration: 'underline'
            fontSize: 16
            position: 'absolute'
            marginTop: 5
            right: 0
            bottom: -20
            display: 'inline-block'
          'Explore this example yourself'


  drawVideo : -> 
        
    VIDEO
      preload: "auto"
      loop: true
      autoPlay: false
      ref: "video"
      controls: @local.ready
      style: 
        marginTop: 1
        position: 'relative'
        width: video_width
        height: video_width * 1080/1920
        border: "1px solid #{caption_color}"
        borderRadius: 8


      for format in ['mp4', 'webm']
        asset_path = asset("product_page/#{VIDEO_FILE}.#{format}")
        if asset_path?.length > 0
          SOURCE
            src: asset_path
            type: "video/#{format}"

  drawCaptions: -> 
    chapter = fetch("video_chapter")

    DIV 
      style: _.extend {}, h1,
        fontWeight: 400
        whiteSpace: 'nowrap'
        paddingBottom: 5
        position: 'relative'
        zIndex: 1
        width: video_width - 1
        color: caption_color #if @local.ready then 'white'

      if !@local.ready  || !chapter.caption
        'This demo shows how Consider.it works'
      else
        chapter.caption


      SVG 
        height: 10
        width: 60

        style:
          position: 'absolute'
          left: '50%'
          marginLeft: - 60 / 2
          bottom: -11

        POLYGON
          points: "0,0 30,10 60,0" 
          fill: caption_color

        POLYGON
          points: "0,-1 30,9 60,-1" 
          fill: 'white'



      # restart video
      DIV 
        style: 
          position: 'absolute'
          right: -56
          top: 0
          cursor: 'pointer'
          color: caption_color
          opacity: if @local.hover_reset || !@local.ready then 1 else .5

        onMouseEnter: => 
          @local.hover_reset = true 
          save @local
        onMouseLeave: => 
          @local.hover_reset = false 
          save @local
          

        onClick: => @startVideo()

        I 
          className: "fa #{if @local.ready then 'fa-refresh' else 'fa-play'}"
          style:
            fontSize: 42


        if @local.ready
          DIV 
            style: 
              fontSize: 14
              lineHeight: 0

            'restart'


  drawChapterMenu : -> 
    current_chapter = fetch("video_chapter")

    UL 
      style:
        position: 'absolute'
        top: 100
        left: -130
        listStyle: 'none'
        width: 120
        textAlign: 'right'

      for menu in _.uniq (chapter.menu for chapter in chapters)
        do (menu) =>
          highlighted = menu == current_chapter.menu
          LI
            onMouseEnter: => 
              @local.hover_chapter = menu 
              save @local
            onMouseLeave: => 
              @local.hover_chapter = null
              save @local

            onClick: => 
              v = @refs.video.getDOMNode()

              chapter = fetch("video_chapter")
              controls = fetch('video_controls')

              chapter_time = 0
              new_chapter = null
              for c, idx in chapters
                if c.menu == menu
                  new_chapter = c
                  break
                chapter_time += c.time

              v.currentTime = chapter_time
              controls.value = chapter_time / v.duration
              chapter.caption = new_chapter?.caption
              chapter.menu = new_chapter?.menu
              save controls
              save chapter

            style: 
              color: if (highlighted || @local.hover_chapter == menu) then current_chapter_color else 'black'
              fontSize: 14
              fontWeight: if highlighted then 700 else 300
              padding: '10px 0'
              cursor: 'pointer'
            menu


  componentDidUpdate: -> @attachToVideo()
  componentDidMount: -> 
    @attachToVideo()

    setTimeout => 
      @startVideo()
    , DEMO_AUTOPLAY_DELAY

  startVideo : -> 
    controls = fetch('video_controls')
    controls.playing = true
    controls.value = 0

    video = @refs.video.getDOMNode()
    video.currentTime = 0      
    video.play()

    @local.ready = true

    save controls
    save @local


  attachToVideo : -> 
    # we use timeupdate rather than tracks / cue changes / vtt
    # because browser implementations are not complete (and often buggy)
    # and polyfills poor. 

    v = @refs.video.getDOMNode()

    if @v != v
      @v = v
      v.addEventListener 'timeupdate', (ev) -> 
        chapter = fetch("video_chapter")
        controls = fetch('video_controls')

        chapter_time = 0
        for c, idx in chapters
          if v.currentTime < chapter_time + c.time || idx == chapters.length - 1
            new_chapter = c
            break
          chapter_time += c.time

        controls.value = v.currentTime / v.duration

        save controls

        if chapter.caption != new_chapter?.caption
          chapter.caption = new_chapter.caption
          chapter.menu = new_chapter.menu
          save chapter
      , false

  # drawVideoControls : ->
  #   VIDEO_SLIDER_WIDTH = 250

  #   controls = fetch('video_controls')

  #   DIV 
  #     onMouseEnter: (ev) => @local.hover_player = true; save @local
  #     onMouseLeave: (ev) => @local.hover_player = false; save @local

  #     style: 
  #       width: VIDEO_SLIDER_WIDTH + 80
  #       margin: 'auto'
  #       position: 'relative'
  #       opacity: if @local.hover_player then 1 else .5
  #       top: -10
  #     I 
  #       className: "fa fa-#{if controls.playing then 'pause' else 'play'}"
  #       onClick: (ev) => 
  #         controls = fetch('video_controls')
  #         controls.playing = !controls.playing
  #         save controls
  #         if controls.playing 
  #           @refs.video.getDOMNode().play()
  #         else
  #           @refs.video.getDOMNode().pause()

  #       style:       
  #         fontSize: 10
  #         color: '#ccc'
  #         #position: 'relative'
  #         padding: '12px 12px'
  #         cursor: 'pointer'
  #         visibility: if @local.hover_player then 'visible' else 'hidden'
  #         left: -12

  #     Slider
  #       key: 'video_controls'
  #       width: VIDEO_SLIDER_WIDTH
  #       handle_height: if @local.hover_player then 20 else 4
  #       base_height: 4
  #       base_color: '#ECECEC'
  #       slider_style: 
  #         margin: 'auto'
  #         position: 'absolute'
  #         top: '50%'
  #         marginTop: -2
  #         left: 40
  #       handle_props: 
  #         color: logo_red

  #       onMouseDownCallback: (ev) =>
  #         video = @refs.video.getDOMNode()
  #         video.pause()

  #       onMouseMoveCallback: (ev) => 
  #         controls = fetch('video_controls')
  #         video = @refs.video.getDOMNode()
  #         video.currentTime = controls.value * video.duration

  #       onMouseUpCallback: (ev) => 
  #         controls = fetch('video_controls')
  #         video = @refs.video.getDOMNode()
  #         video.play() if controls.playing

  #       onClickCallback: (ev) =>
  #         controls = fetch('video_controls')
  #         video = @refs.video.getDOMNode()
  #         video.pause()
  #         video.currentTime = controls.value * video.duration
  #         video.play() if controls.playing  