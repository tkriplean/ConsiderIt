#////////////////////////////////////////////////////////////
# Exploratory reimplemenntation of considerit client in React
#////////////////////////////////////////////////////////////

# Ugliness in this prototype: 
#   - Keeping javascript and CSS variables synchronized
#   - Haven't declared prop types for the components
#   - I don't like setting data as key in props, would rather 
#     have the specific props be added explicitly
#   - NewPoint CSS/HTML is still bulky, waiting on redesign
#   - Managing top_level_component in Router
#   - Possibility of bugs being introduced by having (1) nested components
#     fetching data from cache and (2) immutability of @props. For (2), 
#     could we use object.freeze()? 
#     https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/freeze

# React aliases
R = React.DOM
ReactTransitionGroup = React.addons.TransitionGroup

# Constants
TRANSITION_SPEED = 700   # Speed of transition from results to crafting (and vice versa) 
BIGGEST_POSSIBLE_AVATAR_SIZE = 50
HISTOGRAM_WIDTH = 540    # Width of the slider / histogram base 
MAX_HISTOGRAM_HEIGHT = 200
DECISION_BOARD_WIDTH = 544


##
# StyleAnimator mixin
# Helper for components that implement animations.
StyleAnimator = 
  componentDidMount : -> @applyStyles false

  componentDidUpdate : (prev_props, prev_state) -> @applyStyles prev_props.state != @props.state  

  # Define this method in any Component implementing StyleAnimator
  #applyStyles : (animate = true) -> 

  applyStylesToElements : (styles, duration) ->
    $el = $(@getDOMNode())
    _.each _.keys(styles), (selector) -> 
      # Only apply styles if there are differences, for performance. 
      # This check doesn't work for transform properties because for Velocity we 
      # specify them as e.g. TranslateX: 4 rather than transform: translateX(4)
      styles_for_selector = styles[selector]
      styles_to_apply = {}
      $target = $el.find(selector)

      prop_map = $target.css(_.keys(styles_for_selector))
      if prop_map
        for property in _.keys(styles_for_selector)
          if prop_map[property] != styles_for_selector[property]
            styles_to_apply[property] = styles_for_selector[property]

      if _.size(styles_to_apply) > 0
        $target.velocity styles_to_apply, {duration}

##
# Helper methods that should probably go elsewhere
getStanceSegment = (value) ->
  if value < stanceSegmentBoundaries[1]
    return 0
  else if value < stanceSegmentBoundaries[2]
    return 1
  else if value < stanceSegmentBoundaries[3] 
    return 2
  else if value < stanceSegmentBoundaries[4]
    return 3
  else if value < stanceSegmentBoundaries[5]
    return 4
  else if value < stanceSegmentBoundaries[6]
    return 5
  else
    return 6

stanceSegmentBoundaries = { 0 : -1, 1 : -.9999, 2 : -0.5, 3 : -0.05, 4 : 0.05, 5 : 0.5, 6 : .9999 } 

## ##################
# React Components
#
# These are the components and their relationships:
#                       Proposal
#                   /      |           \            \
#    CommunityPoints   DecisionBoard   Histogram    Slider
#               |          |
#               |      YourPoints
#               |    /            \
#              Point             NewPoint


##
# Proposal
# The mega component for a proposal.
# Has proposal description, feelings area (slider + histogram), and reasons area
Proposal = React.createClass
  mixins: [StyleAnimator]
  displayName: 'Proposal'

  ##
  # Component defaults

  getDefaultProps : ->
    state : 'crafting'
    data :  # would rather have each of these data items added to top level props dict
      proposal : {}
      points : {}
      users : {}
      included_points : []
      initial_stance : 0.0
      opinions : []

  getInitialState : ->
    users_to_highlight_in_histogram : []
    selected_segment_in_histogram : null

  # TODO: add prop types here


  ##
  # Lifecycle methods

  componentDidMount : ->
    @setPointMouseover()

  componentDidUpdate : (prev_props, prev_state) ->
    @setStickyHeader()

  ####
  # On hovering over a point, highlight the people who included this point in the Histogram.
  #
  # This requires cross-component communication. By handling it here in the parent: 
  #    + we eliminate confusing intercomponent communication and callback passing
  #    - it might be unintuitive to find this handler here and not in Point or CommunityPoints
  # 
  # Another decision point is whether to do the work of manipulating the histogram here, or somehow
  # alert the Histogram component to the fact that certain users should be highlighted. Both approaches
  # have strengths and weaknesses:
  #    1) Handle histogram here just using instance variable and jQuery
  #       + Everything in a single place
  #       - Code is susceptible to weird edge cases because it avoids tracking this state with state or props. 
  #         For example, if we switch to crafting somehow without leaving the point.
  #
  #    2) Set props on Proposal that only histogram responds to
  #       + Application state remains tracked by props and state, the React way. Probably less error prone
  #       - Could be performance intense if other proposal components have to get rerendered (even if just in virtual DOM)
  setPointMouseover : ->
    $el = $(@getDOMNode())

    $el.on 'mouseenter mouseleave', '.points_by_community .point_content', (ev) => 
      if @props.state == 'results'
        if ev.type == 'mouseenter'
          point_id = $(ev.currentTarget).parent().data('id')
          point = fetch { url: "points/#{point_id}?no_comments" }

          # get includers of the point
          # TODO: need to add this user if they've included this point (might be already taken care of depending on how saving opinions works)
          includers = point.includers

          ####
          # implement option (1) above:

          # $histogram = $el.find('.histogram')
          # @$includers_to_highlight = $histogram.find ("#avatar-#{uid}" for uid in includers).join(',')
          # @$includers_to_highlight.css { border: '2px solid red' }

          ####
          # implement option (2) above
          @setState { users_to_highlight_in_histogram : includers }

        else if ev.type == 'mouseleave'
          ####
          # implement option (1) above

          #@$includers_to_highlight.css { border: '' }

          ####
          # implement option (2) above
          @setState { users_to_highlight_in_histogram : [] }

  setStickyHeader : ->
    # Sticky decision board. It is here because the calculation of offset top would 
    # be off if we did it in DidMount before all the data has been fetched from server
    if @props.state == 'crafting'
      _.delay => 
        $el = $(@getDOMNode())
        $cons = $el.find('.cons_by_community')
        $opinion = $el.find('.opinion_region')

        $el.find('.opinion_region').headroom
          offset: $('.opinion_region').offset().top

          onNotTop : => 
            return if @props.state != 'crafting'
            $opinion.css {position: 'fixed', top: '0' }

          onTop : => 
            return if @props.state != 'crafting'
            $opinion.css { position: '', top: '' }
            
      , 1000  # delay initialization to let the rest of the dom load so that the offset is calculated properly

  ##
  # State-dependent styling
  applyStyles : (animate = true) ->  
    $el = $(@getDOMNode())
    duration = if animate then TRANSITION_SPEED else 0

    # Note: Velocity requires properties to be pulled out (e.g. paddingLeft, translateX, rather than using padding or transform)
    # Note: Use velocity even for 0 duration applications to maintain parity of style definition
    switch @props.state
      when 'crafting'
        styles = 
          '.histogram_bar':                          { opacity: '.2' }
          '.opinion_region':                         { translateX: 0, translateY: 0 }
          '.decision_board_body':                    { width: "#{DECISION_BOARD_WIDTH}px", minHeight: "375px"}
          '.pros_by_community':                      { translateX: 0 }
          '.cons_by_community':                      { translateX: "#{DECISION_BOARD_WIDTH}px" }
        
        @applyStylesToElements styles, duration

        $el.find('.give_opinion_button').css 'visibility', 'hidden'
        _.delay -> 
          $el.find('.your_points').css 'display', ''
        , duration

      when 'results'
        slider_stance = ($el.find('.ui-slider').slider('value') + 1) / 2
        is_opposer = slider_stance > .5
        opinion_region_x = DECISION_BOARD_WIDTH * slider_stance
        give_opinion_button_width = 186
        opinion_region_x -= give_opinion_button_width / 2 

        styles = 
          '.histogram_bar':                          { opacity: '1' }
          '.opinion_region':                         { translateX: opinion_region_x, translateY: -18 }
          '.decision_board_body':                    { width: "#{give_opinion_button_width}px", minHeight: "32px"}
          '.pros_by_community':                      { translateX:  DECISION_BOARD_WIDTH / 2 }
          '.cons_by_community':                      { translateX:  DECISION_BOARD_WIDTH / 2 }
        
        @applyStylesToElements styles, duration

        $el.find('.your_points').css 'display', 'none'
        _.delay -> 
          $el.find('.give_opinion_button').css 'visibility', ''
        , duration

  ##
  # State needs to be updated

  toggleState : (ev) ->
    route = if @props.state == 'results' then Routes.new_opinion_proposal_path(@props.data.proposal.long_id) else Routes.proposal_path(@props.data.proposal.long_id)
    app_router.navigate route, {trigger : true}
  
  onSelectSegment : ( segment ) ->
    @setState
      selected_segment_in_histogram : segment

  ##
  # Make this thing!
  render : ->
    stance_names = 
      0 : 'Diehard Supporter'
      6 : 'Diehard Opposer'
      1 : 'Strong Supporter'
      5 : 'Strong Opposer'
      2 : 'Supporter'
      4 : 'Opposer'
      3 : 'Neutral'

    R.div className:'proposal', key:@props.long_id, 'data-state':@props.state,
      
      #description
      R.div className:'description_region',
        Avatar className: 'proposal_proposer', user: @props.data.proposal.user_id, tag: R.img, img_style: 'large'
        R.div className: 'proposal_category', "#{@props.data.proposal.category} #{@props.data.proposal.designator}"
        R.h1 className:'proposal_heading', @props.data.proposal.name
        R.div className:'proposal_details', dangerouslySetInnerHTML:{__html: @props.data.proposal.description}

      #toggle
      R.div className:'toggle_state_region',
        R.h1 className:'proposal_state_primary',
          if @props.state == 'crafting' then 'Give your Opinion' else 'Explore all Opinions'
        R.div className:'proposal_state_secondary', 
          'or '
          R.a onClick: @toggleState,
            if @props.state != 'crafting' then 'Give Own Opinion' else 'Explore all Opinions'
    
      #feelings
      R.div className:'feelings_region',
        Histogram
          state: @props.state
          opinions: @props.data.opinions
          users_to_highlight_in_histogram: @state.users_to_highlight_in_histogram
          onSelectSegment: @onSelectSegment
          selected_segment_in_histogram: @state.selected_segment_in_histogram

        Slider
          initial_stance: @props.data.initial_stance
          stance_names: stance_names 
          state: @props.state

      #reasons
      R.div className:'reasons_region',
        #community pros
        CommunityPoints 
          key: 'pros'
          state: @props.state
          valence: 'pro'
          included_points : @props.data.included_points
          points: fetch { url: 'all_points' }
          opinions: @props.data.opinions          
          selected_segment_in_histogram: @state.selected_segment_in_histogram
          stance_names: stance_names
          
        #your reasons
        DecisionBoard
          state: @props.state
          included_points : @props.data.included_points
          toggleState: @toggleState
          points: fetch { url: 'all_points' }

        #community cons
        CommunityPoints 
          key: 'cons'
          state: @props.state
          valence: 'con'
          included_points : @props.data.included_points
          points: fetch { url: 'all_points' }
          opinions: @props.data.opinions
          selected_segment_in_histogram: @state.selected_segment_in_histogram
          stance_names: stance_names

##
# Histogram
Histogram = React.createClass

  getDefaultProps : ->
    opinions: []
    selected_segment_in_histogram: null

  ##
  # buildHistogram
  # Split up opinions into segments. For now we'll keep three hashes: 
  #   - all opinions
  #   - high level segments (the seven original segments, strong supporter, neutral, etc)
  #   - small segments that represent individual columns in the histogram, now that 
  #     we do not have wide bars per se
  buildHistogram : ->
    ##
    # Size the avatars. Size of avatar shrinks proportional to 1/sqrt(num_opinions)
    avatar_size = Math.min BIGGEST_POSSIBLE_AVATAR_SIZE, Math.floor(BIGGEST_POSSIBLE_AVATAR_SIZE / Math.sqrt( (@props.opinions.length + 1) / 10 )  )

    # Calculate (approximately) how many columns of opinions to put on the histogram. 
    columns_in_histogram = Math.floor(HISTOGRAM_WIDTH / avatar_size)

    max_slider_variance = 2.0 # Slider stances vary from -1.0 to 1.0. 

    # Assign each column in the histogram to a segment. Each column is an 
    # empty array which will eventually hold opinions.
    segments = ( [] for segment in [0..6] )
    for col in [0..columns_in_histogram]
      segment = getStanceSegment(max_slider_variance * col / columns_in_histogram - 1)
      segments[segment].push []

    segments[3].push([]) while segments[3].length < 3   # ensure neutral segment has 3 columns

    # Assign each Opinion to a column
    # This gets complicated because we treat the extremes and Neutral differently. 
    #  - The number of columns in the extremes is variable, with the max number of opinions per columns capped. 
    #    Here we'll dynamically grow the number of cols in each extreme, subdividing the cols whenever they
    #    hit their max number. 
    #  - There are three columns for Neutral. We distributed the opinions evenly across these three. 
    #  - Opinions belonging to other places along the spectrum are mapped directly to the column associated 
    #    with that stance.     
    opinions_in_segment = {0:0, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0}
    max_opinions_in_column = Math.floor MAX_HISTOGRAM_HEIGHT / avatar_size
    for opinion in @props.opinions
      segment = getStanceSegment opinion.stance

      # If this is a Neutral opinion, fill up all three neutral cols equally
      if segment == 3
        segments[3][opinions_in_segment[3] % 3].push opinion

      # If this is an extreme opinion...
      else if segment in [0,6]
        if segments[segment][segments[segment].length - 1].length == max_opinions_in_column - 1
          segments[segment].push []

        segments[segment][segments[segment].length - 1].push opinion

      # If this opinion is somewhere else on the spectrum...
      else
        adjusted_stance = Math.abs(opinion.stance - stanceSegmentBoundaries[segment])
        col_width = Math.abs(stanceSegmentBoundaries[segment + 1] - stanceSegmentBoundaries[segment])/segments[segment].length
        segments[segment][Math.floor(adjusted_stance / col_width)].push opinion

      opinions_in_segment[segment] += 1

    num_columns = _.flatten(_.values(segments), true).length
    [num_columns, segments, avatar_size]

  onSelectSegment : (ev) ->
    if @props.state == 'results'
      segment = $(ev.currentTarget).data('segment')
      # if clicking on already selected segment, then we'll deselect
      @props.onSelectSegment if @props.selected_segment_in_histogram == segment then null else segment

  render : ->
    [num_columns, segments, avatar_size] = @buildHistogram() #todo: memoize
    effective_histogram_width = num_columns * avatar_size
    margin_adjustment = -(effective_histogram_width - HISTOGRAM_WIDTH)/2
    margin_adjustment -= - (segments[0].length - segments[6].length) / 2 * avatar_size #make sure that the neutral segment is centered

    R.table className: 'histogram', style: { width: effective_histogram_width, marginLeft: margin_adjustment }, 
      R.tr null, 
        for bars, segment in segments.reverse()
          R.td className:"histogram_segment", key:segment, onClick: @onSelectSegment, 'data-segment':segment, style : { opacity: if !@props.selected_segment_in_histogram? || @props.selected_segment_in_histogram == segment then '1' else '.2' },
            R.table null,
              R.tr null,
                for bar in bars
                  R.td className:"histogram_bar", style: {width: avatar_size},
                    for opinion in bar
                      Avatar key:"#{opinion.user_id}", user: opinion.user_id, 'data-segment':segment, style:{height: avatar_size, width: avatar_size, border: if _.contains(@props.users_to_highlight_in_histogram, opinion.user_id) then '1px solid red' else 'none'}

##
# Slider
# Manages the slider and the UI elements attached to it. 
Slider = React.createClass
  displayName: 'Slider'
  mixins: [StyleAnimator]

  getInitialState : ->
    stance_segment : getStanceSegment(@props.initial_stance)

  componentDidMount : -> 
    @setSlidability()

  componentDidUpdate : (prev_props, prev_state) ->
    @setSlidability()

  # We have a separate applyStyle here from Proposal because the Slider component
  # gets rerendered more frequently than the Proposal component (i.e. when the 
  # slider is being slid...forcing the entire Propoosal component to rerender
  # causes terrible performance).
  applyStyles : (animate = false) ->
    duration = if animate then TRANSITION_SPEED else 0
    $el = $(@getDOMNode())

    mouth_scaler = if @state.stance_segment <= 3 then -1 else 1
    mouth_x = if @state.stance_segment == 3 then 0 else -7.5

    switch @props.state
      when 'crafting'
        styles = 
          '.bubblemouth': { scaleX: mouth_scaler * 1.5, scaleY: 1.5, translateY: 4.35, translateX: mouth_x * 1.5  }
          '.the_handle':  { scale: 2.5, translateY: -8 }

      when 'results'
        styles = 
          '.bubblemouth': { scaleX: mouth_scaler, scaleY: 1, translateY: -8, translateX: mouth_x  }
          '.the_handle':  { scale: 1, translateY: -9 }

    @applyStylesToElements styles, duration

  ##
  # setSlidability
  # Inits jQuery UI slider and enables/disables it between states
  setSlidability : ->
    $slider_base = $(@getDOMNode()).find('.slider_base')
    if $slider_base.hasClass "ui-slider"
      $slider_base.slider(if @props.state == 'results' then 'disable' else 'enable') 
    else
      $slider_base.slider
        disabled: @props.state == 'results'
        min: -1
        max: 1
        step: .01
        value: @props.initial_stance
        slide: (ev, ui) => 
          # update the stance segment if it has changed. This facilitates the feedback atop
          # the slider changing from e.g. 'strong supporter' to 'neutral'
          segment = getStanceSegment ui.value
          if @state.stance_segment != segment
            @setState
              stance_segment : segment
              stance : ui.value

  getSliderValue : -> $(@getDOMNode()).find('.ui-slider-handle').position().left / $el.find('.slider_base').innerWidth()

  render : ->
    R.div className: 'slider',
      R.div className:'slider_base', 
        R.div className:'ui-slider-handle', #jquery UI slider will pick an el with this class name up
          R.div className: 'the_handle'
          R.img className:'bubblemouth', src: if @state.stance_segment == 3 then '/assets/bubblemouth_neutral.png' else '/assets/bubblemouth.png'
          R.div className:'slider_feedback', 
            R.div className:'slider_feedback_label', "You are#{if @state.stance_segment == 3 then '' else ' a'}"
            R.div className:'slider_feedback_result', @props.stance_names[@state.stance_segment]
            R.div className:'slider_feedback_instructions', 'drag to change'

      R.div className:'slider_labels', 
        R.h1 className:"histogram_label histogram_label_support", 'Support'
        R.h1 className:"histogram_label histogram_label_oppose", 'Oppose'


##
# DecisionBoard
# Handles the user's list of important points in crafting state. 
DecisionBoard = React.createClass
  displayName: 'DecisionBoard'

  componentDidMount : ->
    # make this a drop target
    $el = $(@getDOMNode()).parent()
    $el.droppable
      accept: ".community_point .point_content"
      drop : (ev, ui) =>
        ui.draggable.parent().velocity 'fadeOut', 200, => 
          save { type: 'point_inclusion', data: ui.draggable.parent().data('id') }
        $el.removeClass "user_is_hovering_on_a_drop_target"
      out : (ev, ui) => $el.removeClass "user_is_hovering_on_a_drop_target"
      over : (ev, ui) => $el.addClass "user_is_hovering_on_a_drop_target"

  render : ->
    R.div className:'opinion_region', 
      R.div className:'decision_board_body',

        # only shown during crafting, but needs to be present always for animation
        R.div className: 'your_points',
          # your pros
          YourPoints
            state: @props.state
            included_points: @props.included_points
            valence: 'pro'

          # your cons
          YourPoints
            state: @props.state
            included_points: @props.included_points
            valence: 'con'

        # only shown during results, but needs to be present always for animation
        R.a className:'give_opinion_button', onClick: @props.toggleState, 'Give your Opinion'


##
# Mixin for Point lists for handling draggability (CommunityPoints and YourPoints)
# Bonus: prevents the need to pass state to Point (which results in expensive operations)
#
DraggablePoints = 
  componentDidMount : -> @setDraggability()
  componentDidUpdate : -> @setDraggability()

  setDraggability : ->
    # Ability to drag include this point if a community point, 
    # or drag remove for point on decision board
    # also: disable for results page

    disable = @props.state == 'results'
    $(@getDOMNode()).find('.point_content').each -> 
      if $(@).hasClass "ui-draggable"
        $(@).draggable(if disable then 'disable' else 'enable') 
      else
        $(@).draggable
          revert: "invalid"
          disabled: disable


##
# YourPoints
# List of important points for the active user. 
# Two instances used for Pro and Con columns. Shown as part of DecisionBoard. 
# Creates NewPoint instances.
YourPoints = React.createClass
  displayName: 'YourPoints'
  mixins: [DraggablePoints]

  render : ->

    R.div className:"points_on_decision_board #{@props.valence}s_on_decision_board",
      R.h1 className:'points_heading_label',
        "Your #{@props.valence.charAt(0).toUpperCase()}#{@props.valence.substring(1)}s"

      R.ul null,
        for point_id in @props.included_points
          point = fetch { url: "points/#{point_id}?no_comments" }
          if point.is_pro == (@props.valence == 'pro')
            Point 
              key: point.id
              id: point.id
              nutshell: point.nutshell
              text: point.text
              valence: @props.valence
              comment_count: point.comment_count
              author: point.user_id
              # state: @props.state
              location_class: 'decision_board_point'

        R.div className:'add_point_drop_target',
          R.img className:'drop_target', src:"/assets/drop_target.png"
          R.span className:'drop_prompt',
            "Drag #{@props.valence} points from the #{if @props.valence == 'pro' then 'left' else 'right'} that resonate with you."

        NewPoint 
          valence: @props.valence

##
# CommunityPoints
# List of points contributed by others. 
# Shown in wing during crafting, in middle on results. 
CommunityPoints = React.createClass
  displayName: 'CommunityPoints'
  mixins: [DraggablePoints]

  componentDidMount : ->
    # Make this a drop target to facilitate removal of points
    $el = $(@getDOMNode())
    $el.droppable
      accept: ".decision_board_point.#{@props.valence} .point_content"
      drop : (ev, ui) =>
        ui.draggable.parent().velocity 'fadeOut', 200, => 
          save { type: 'point_removal', data: ui.draggable.parent().data('id') }

          $el.removeClass "user_is_hovering_on_a_drop_target"
      out : (ev, ui) => $el.removeClass "user_is_hovering_on_a_drop_target"
      over : (ev, ui) => $el.addClass "user_is_hovering_on_a_drop_target"

  render : ->

    #filter to pros or cons & down to points that haven't been included
    points = _.filter fetch({ url: 'all_points' }), (pnt) =>
      is_correct_valence = pnt.is_pro == (@props.valence == 'pro')
      has_not_been_included = @props.state == 'results' || !_.contains(@props.included_points, pnt.id)
      is_correct_valence && has_not_been_included

    if @props.selected_segment_in_histogram?
      # If there is a histogram segment selected, we'll have to filter down 
      # to the points that users in this segment think are important, and 
      # order them by resonance to those users. I'm doing this quite inefficiently.
      point_inclusions_per_point_for_segment = {} # map of points to including users
      _.each @props.opinions, (opinion) =>
        if opinion.stance_segment == 6 - @props.selected_segment_in_histogram && opinion.point_inclusions
          for point_id in opinion.point_inclusions
            if !_.has(point_inclusions_per_point_for_segment, point_id)
              point_inclusions_per_point_for_segment[point_id] = 1
            else
              point_inclusions_per_point_for_segment[point_id] += 1

      points = _.filter points, (pnt) -> _.has point_inclusions_per_point_for_segment, pnt.id
      points = _.sortBy points, (pnt) -> -point_inclusions_per_point_for_segment[pnt.id]
    else
      # Default sort order
      points = _.sortBy points, (pnt) => - if @props.state == 'results' then pnt.score else pnt.persuasiveness

    label = "#{@props.valence.charAt(0).toUpperCase()}#{@props.valence.substring(1)}"

    R.div className:"points_by_community #{@props.valence}s_by_community",
      R.h1 className:'points_heading_label', if @props.state == 'results' then "Top #{label}s" else "Others' #{label}s"
      R.p className:'points_segment_label', if !@props.selected_segment_in_histogram? then '' else "for #{@props.stance_names[@props.selected_segment_in_histogram]}s"          

      R.ul null, 
        for point in points
          Point 
            key: point.id
            id: point.id
            nutshell: point.nutshell
            text: point.text
            valence: @props.valence
            comment_count: point.comment_count
            author: point.user_id
            # state: @props.state
            location_class : 'community_point'

##
# Point
# A single point in a list. 
Point = React.createClass
  displayName: 'Point'

  getInitialState : ->
    show_details : false

  componentDidMount : ->
    @setShowDetails()

  setShowDetails : ->
    $(@getDOMNode()).click (ev) => 
      @setState { show_details : !@state.show_details }

  render : -> 
    R.li className: "point closed_point #{@props.location_class} #{@props.valence}", 'data-id':@props.id,
      Avatar tag: R.a, user: @props.author, className:"point_author_avatar"
      
      R.div className:'point_content',
        R.div className:'point_nutshell',
          @props.nutshell
          if @props.text
            if @state.show_details
              R.div className: 'point_details', dangerouslySetInnerHTML:{__html: @props.text}
            else
              R.span className: 'point_details_tease', $("<span>#{@props.text[0..30]}</span>").text() + "..."

        # R.a className:'open_point_link',
        #   "#{@props.comment_count} comment#{if @props.comment_count != 1 then 's' else ''}"

##
# NewPoint
# Handles adding a new point into the system. Only rendered when proposal is in Crafting state. 
# Manages whether the user has clicked "add a new point". If they have, show new point form. 
NewPoint = React.createClass
  displayName: 'NewPoint'

  getInitialState : ->
    editMode : false

  handleAddPointBegin : (ev) ->
    @setState { editMode : true }

  handleAddPointCancel : (ev) ->
    @setState { editMode : false }

  handleSubmitNewPoint : (ev) ->
    $form = $(@getDOMNode())

    point =
      nutshell : $form.find('#nutshell').val()
      text : $form.find('#text').val()
      is_pro : @props.valence == 'pro'
      user_id : -2 #anon user
      comment_count : 0 
 
    save { type: 'point', data: point }

    @setState { editMode : false }

  render : ->
    #TODO: refactor HTML/CSS for new point after we get better sense of new point redesign
    valence_capitalized = "#{@props.valence.charAt(0).toUpperCase()}#{@props.valence.substring(1)}"

    R.div className:'newpoint',
      if !@state.editMode
        R.div className:'newpoint_prompt',
          R.span className:'qualifier', 
            'or '
          R.span className:'newpoint_bullet', dangerouslySetInnerHTML:{__html: '&bull;'}
          R.a className:'newpoint_link', 'data-action':'write-point', onClick: @handleAddPointBegin,
            "Write a new #{valence_capitalized}"
      else
        R.div className:'newpoint_form',
          R.input id:'is_pro', name: 'is_pro', type: 'hidden', value: "#{@props.valence == 'pro'}"
          R.div className:'newpoint_nutshell_wrap',
            R.textarea id:'nutshell', className:'newpoint_nutshell is_counted', cols:'28', maxLength:"140", name:'nutshell', pattern:'^.{3,}', placeholder:'Summarize your point (required)', required:'required'
            R.span className: 'count', 140
          R.div className:'newpoint_description_wrap',
            R.textarea id:'text', className:'newpoint_description', cols:'28', name:'text', placeholder:'Write a longer description (optional)', required:'required'
          R.div className:'newpoint_hide_name',
            R.input className:'newpoint-anonymous', type:'checkbox', id:"hide_name-#{@props.valence}", name:"hide_name-#{@props.valence}"
            R.label for:"hide_name-#{@props.valence}", title:'We encourage you not to hide your name from other users. Signing your point with your name lends it more weight to other participants.', 
              'Conceal your name'
          R.div className:'newpoint-submit',
            R.a className:'newpoint-cancel', onClick: @handleAddPointCancel,
              'cancel'
            R.input className:'button', action:'submit-point', type:'submit', value:'Done', onClick: @handleSubmitNewPoint

##
# Avatar
# Displays a user's avatar
# Supports straight up img src, or using the CSS-embedded b64 for each user
Avatar = React.createClass
  displayName: 'Avatar'

  getDefaultProps : ->
    user: -1 # defaults to anonymous user
    tag: R.img
    img_style: null #null will default to using the css-based b64 embedded images
    className: ''

  componentWillMount : ->
    derived_state = 
      className : "#{@props.className} avatar"
      id : "avatar-#{@props.user}"

    if @props.img_style
      user = fetch {url: "users/#{@props.user}?partial"}
      if !user || !user.avatar_file_name
        derived_state.filename = "/system/default_avatar/#{@props.img_style}_default-profile-pic.png"
      else
        derived_state.filename = "/system/avatars/#{user.id}/#{@props.img_style}/#{user.avatar_file_name}"

    @setState derived_state

  render : ->
    attrs = { className: @state.className, id: @state.id, 'data-id': @props.user } 
    attrs.src = @state.filename if @props.img_style

    @transferPropsTo @props.tag attrs 


##
# Mocks for activeREST
all_users = {} 
all_points = {}

fetch = (options, callback, error_callback) ->
  if options.url[0..3] == 'user'
    return all_users[options.url]
  if options.url[0..4] == 'point'
    return all_points[options.url]
  if options.url[0..9] == 'all_points'
    return _.values all_points

  error_callback ||= (xhr, status, err) -> console.error 'Could not fetch data', status, err.toString()

  $.ajax
    url: options.url
    dataType: 'json'
    success: (data) =>
      if options.type == 'proposal' || true #assume fetching proposal
        # Build hash of user information
        data.users = $.parseJSON data.users
        for user in data.users
          all_users["users/#{user.id}?partial"] = user

        #TODO: return from server as a hash already?
        for point in data.points
          point.includers = $.parseJSON point.includers
          all_points["points/#{point.id}?no_comments"] = point

        for opinion in data.opinions
          opinion.point_inclusions = $.parseJSON opinion.point_inclusions


      console.log data
      callback data

    error: error_callback

#save assumes that data is a proposal page
save = (action) -> 
  proposal_data = $.extend true, {}, top_level_component.props #deep clone so that shouldcomponentupdate will note changes to data    

  switch action.type
    when 'point'

      get_unique_id = ->
        id = -1
        while _.has all_points, "points/#{id}?no_comments"
          id = -(Math.floor(Math.random() * 999999) + 1)
        id

      # proposal_data = $.extend true, {}, top_level_component.props, {data: action._proposal_data} #deep clone so that shouldcomponentupdate will note changes to data    
      id = get_unique_id()
      action.data.id = id

      action.data.includers = [current_user_id=-2]
      all_points["points/#{id}?no_comments"] = action.data
      included_points = _.clone proposal_data.included_points
      included_points.push action.data.id

      proposal_data.included_points = included_points

    when 'point_inclusion'
      proposal_data.data.included_points.push action.data

    when 'point_removal'
      proposal_data.data.included_points = _.without proposal_data.data.included_points, action.data

    when 'proposal'
      proposal_data.data = action.data

  top_level_component.setProps proposal_data


## ########################
## Application area

##
# load users' pictures
$.get Routes.get_avatars_path(), (data) -> $('head').append data

##
# Backbone routing
# Note: not committed to backbone. Want to experiment with other routing techniques too.
top_level_component = null
Router = Backbone.Router.extend

  routes :
    #"(/)" : "root"
    ":proposal(/)": "proposal"
    ":proposal/results(/)": "results"
    #":proposal/points/:point(/)" : "openPoint"

  proposal : (long_id, state = 'crafting') ->

    if !top_level_component
      top_level_component = React.renderComponent Proposal({state : state}), document.getElementById('l_content_main_wrap')
      fetch { url: Routes.proposal_path long_id }, (data) => save { type: 'proposal', data: data }
    else
      top_level_component.setProps
        state : state

  results : (long_id) -> @proposal long_id, 'results'

app_router = new Router()

$(document).ready -> Backbone.history.start {pushState: true}
