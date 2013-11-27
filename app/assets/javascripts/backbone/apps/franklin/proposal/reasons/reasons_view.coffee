@ConsiderIt.module "Franklin.Proposal", (Proposal, App, Backbone, Marionette, $, _) ->

  class Proposal.ReasonsLayout extends App.Views.StatefulLayout
    template: '#tpl_reasons_layout'
    className: 'l-message m-reasons'

    regions : 
      positionRegion : '.m-position-region'
      footerRegion : '.m-reasons-footer-region'      
      peerProsRegion : '.m-aggregated-propoints-region'
      peerConsRegion : '.m-aggregated-conpoints-region'
      participantsRegion : '.l-message-speaker'

    initialize : (options = {}) ->
      super options

    onRender : ->
      super

    pointExpanded : (region) ->
      region.$el.css 'zIndex', 12
      $transition_speed = 1000
      @sizeToFit $transition_speed

    pointClosed : (region) ->
      region.$el.css 'zIndex', ''
      $transition_speed = 1000
      @sizeToFit $transition_speed

    pointsBrowsing : (valence) ->
      $transition_speed = 1000

      if valence == 'pro'
        @peerProsRegion.$el.addClass 'm-pointlist-browsing'
        @$el.addClass 'm-reasons-browsing m-reasons-browsing-pros'

      else
        @peerConsRegion.$el.addClass 'm-pointlist-browsing'
        @$el.addClass 'm-reasons-browsing m-reasons-browsing-cons'

      @sizeToFit $transition_speed * 1.5

    pointsBrowsingOff : (valence) ->
      $transition_speed = 1000

      @peerConsRegion.$el.css 
        right: ''
        @positionRegion.$el.css 
          left: ''

      if valence == 'con'
        @peerProsRegion.$el.css 
          left: ''

        @peerConsRegion.$el.removeClass 'm-pointlist-browsing'
        @$el.removeClass 'm-reasons-browsing m-reasons-browsing-cons'

      else
        @peerProsRegion.$el.removeClass 'm-pointlist-browsing'
        @$el.removeClass 'm-reasons-browsing m-reasons-browsing-pros'

      @sizeToFit $transition_speed * 1.5

    _sizeToFit : (minheight) ->
      $to_fit = @$el.find('.m-reasons-lists')

      $to_fit.css 'height', ''
      $to_fit.parent().css 'min-height', ''

      height = Math.max $to_fit.outerHeight(), minheight

      $to_fit.css 'height', height
      $to_fit.parent().css 'min-height', height


    sizeToFit : (delay = 0, minheight = 0) ->
      if delay > 0
        _.delay =>
          @_sizeToFit minheight
        , delay
      else
        @_sizeToFit minheight

    events : 
      'mouseenter .m-point-peer' : 'logPointView'
      'click .m-points-list-region' : 'reasonsClicked'
      'click .m-participants' : 'reasonsClicked'      
      'click .m-reasons-footer-region' : 'reasonsClicked'            
      'mouseenter .m-points-list-region' : 'showViewResults'
      'mouseleave .m-points-list-region' : 'hideViewResults'
      'mouseenter .m-reasons-footer-region' : 'showViewResults'
      'mouseleave .m-reasons-footer-region' : 'hideViewResults'      
      'mouseenter .m-participants' : 'showViewResults'
      'mouseleave .m-participants' : 'hideViewResults'

    logPointView : (ev) ->
      if @state != Proposal.ReasonsState.collapsed
        pnt = $(ev.currentTarget).data('id')
        @trigger 'point:viewed', pnt

    reasonsClicked : (ev) ->
      if @state == Proposal.ReasonsState.collapsed && $(ev.target).closest('.m-reasons-header-region').length == 0
        @trigger 'show_results'
        ev.stopPropagation()

    showViewResults : (ev) ->
      return if @state != Proposal.ReasonsState.collapsed

      @hover_state = true
      @$el.find('.m-reasons-footer-region').css
        visibility: 'visible'

    hideViewResults : (ev) ->
      return if @state != Proposal.ReasonsState.collapsed || $(ev.target).closest('.m-reasons-view-results').length > 0
      @hover_state = false
      _.delay =>
        if !@hover_state
          @$el.find('.m-reasons-footer-region').css
            visibility: ''
      , 100

  class Proposal.ResultsFooterView extends App.Views.ItemView
    template : '#tpl_aggregate_footer_expanded'
    className : 'm-reasons-footer-sticky'

    serializeData : ->
      user_position = @model.getUserPosition()
      _.extend {}, @model.attributes,
        call : if user_position && user_position.get('published') then 'Update your position' else 'What do you think? Click to contribute your own position.'

  class Proposal.ResultsFooterCollapsedView extends App.Views.ItemView
    template : '#tpl_aggregate_footer_collapsed'

    serializeData : ->
      _.extend {}, @model.attributes

  class Proposal.ResultsFooterSeparatedView extends App.Views.ItemView
    template : '#tpl_aggregate_footer_separated'

    serializeData : ->
      _.extend {}, @model.attributes