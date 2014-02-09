@ConsiderIt.module "Franklin.Points", (Points, App, Backbone, Marionette, $, _) ->
  
  class Points.PointListLayout extends App.Views.StatefulLayout
    template: '#tpl_points'

    regions : 
      headerRegion : '.pointlist-header-region'
      listRegion : '.pointlist-list-region'
      footerRegion : '.pointlist-footer-region'

    initialize : (options={}) ->
      super options

  class Points.ExpandablePointList extends Points.PointListLayout
    template: '#tpl_points_expandable'

  class Points.PeerPointList extends Points.ExpandablePointList
    className : => 
      "peer-reasons reasons-peer-#{@options.valence}s"

  class Points.UserReasonsList extends Points.PointListLayout
    className : => 
      "position-points position-#{@options.valence}points"

    onRender : ->
      super

  class Points.PointList extends App.Views.CollectionView
    tagName : 'ul'
    className : 'point-list'

    initialize : (options = {}) ->
      @itemView = options.itemView
      @emptyView = options.emptyView
      @location = options.location
      super options

    buildItemView : (point, itemview, options) ->
      if itemview == Points.PeerEmptyView
        new itemview()
      else
        valence = if point.attributes.is_pro then 'pro' else 'con'
        view = new @itemView
          model : point
          attributes : 
            'data-id': "#{point.id}"
            'data-role': 'point'
            includers : "#{point.get('includers')}"
            class : "point closed_point point-#{@location} #{valence}"

        view

  class Points.PointListHeader extends App.Views.ItemView
    template : '#tpl_points_header'
    sort : null

    initialize : (options = {}) ->
      super options
      @sort = options.sort || @sort

    serializeData : ->
      header : @getHeaderText()

    processValenceForHeader : ->
      tenant = App.request 'tenant:get'
      valence = if @options.valence == 'pro' then tenant.getProLabel({capitalize:true,plural:true}) else tenant.getConLabel({capitalize:true,plural:true})
      valence


    getHeaderText : ->
      @processValenceForHeader()

    requestSort : (sort_by) ->
      @sort = sort_by

      @trigger 'sort', sort_by

    onShow : ->      
      @requestSort(@sort) if @sort
      @listenTo @collection, 'reset', =>  
        @render()

  class Points.UserReasonsPointListHeader extends Points.PointListHeader
    getHeaderText : ->
      valence = @processValenceForHeader()
      "List Your #{valence}"


  class Points.ExpandablePointListHeader extends Points.PointListHeader
    template : '#tpl_points_expandable_header'
    is_expanded : false
    sort : 'score'    
    
    initialize : (options = {}) ->
      super options
      @collection = options.collection
      @is_expanded = @setExpanded(options.expanded) if options.expanded
      @segment = options.segment

    setExpanded : (expand) ->
      @is_expanded = expand
      @render()

      if @is_expanded
        # unexpand when clicking outside of pointlist
        $(document).on 'click.unexpand_points', (ev)  => 
          if $(ev.target).closest('.pointlist-sort-option').length == 0 && $(ev.target).closest('.unexpand_points')[0] != @$el[0] && $('.open_point, .l-dialog-detachable').length == 0
            @trigger 'points:toggle_expanded', true
            ev.stopPropagation()

        $(document).on 'keyup.unexpand_points', (ev) => 
          if ev.keyCode == 27 && $('.open_point, .l-dialog-detachable').length == 0
            @trigger 'points:toggle_expanded', true
            ev.stopPropagation()
      else
        $(document).off '.unexpand_points'
        # @$el.off '.unexpand_points'
        @$el.ensureInView {fill_threshold: .5}

    serializeData : ->
      data = super
      tenant = App.request 'tenant:get'
      params = _.extend data,
        pros : @options.valence == 'pro'
        sort_by : @sort
        is_expanded : @is_expanded
        sorts : [ 
          { name: 'Persuasiveness', title: 'Considerations that are proportionately better at convincing other people to add them to their pro/con list are rated higher. Newer considerations that have been seen by fewer people may be ranked higher than the most popular considerations.', target: 'persuasiveness'}, 
          { name: 'Popularity', title: 'Considerations that have been added to the most pro/con lists are ranked higher.', target: 'score'}, 
          { name: "Newest", title: 'The newest considerations are shown first.', target: 'created_at' } ]
          # { name: 'Common Ground', title: 'Considerations that tend to be added by both supporters and opposers are ranked higher. Low ranked considerations are more divisive.', target: '-divisiveness'}]
      params

    onRender : ->
      @selectSort()

    getHeaderText : ->
      valence = @processValenceForHeader()
      modifier = switch @sort
        when 'score'
          'Top'
        when 'persuasiveness'
          'Persuasive'
        when 'created_at'
          'New'
        else
          '' 

      tail = if modifier == '' then "for #{App.Entities.Position.stance_name(@segment)}" else ''


      $.trim "#{modifier} #{valence} #{tail}"

    selectSort : ->
      @$el.find("[data-target]").removeClass 'selected'
      @$el.find("[data-target='#{@sort}']").addClass 'selected'

    events : _.extend {}, Points.PointList.prototype.events,
      'click .pointlist-sort-option a' : 'sortList'
      'click [data-target="expand-toggle"]' : 'handleExpandToggle'

    sortList : (ev) ->
      sort_by = $(ev.target).data('target')
      @requestSort sort_by
      @selectSort()
      ev.stopPropagation()

    handleExpandToggle : (ev) ->
      @trigger 'points:toggle_expanded', @is_expanded
      ev.stopPropagation()

  class Points.ExpandablePointListFooter extends App.Views.ItemView
    template : '#tpl_points_expandable_footer'
    is_expanded : false

    initialize : (options = {}) ->
      @collection = options.collection

    setExpanded : (expanded) ->
      @is_expanded = expanded
      @render()

    onShow : ->
      @listenTo @collection, 'reset', =>  
        @render()

    serializeData : ->
      data = super
      tenant = App.request 'tenant:get'
      params = _.extend data,
        cnt : _.size @collection.fullCollection
        has_more_points : @collection.state.totalPages > 1
        is_expanded : @is_expanded
        label : if @options.valence == 'pro' then tenant.getProLabel({capitalize:true, plural:true}) else tenant.getConLabel({capitalize:false, plural:true})        

      params

    events : 
      'click [data-target="expand-toggle"]' : 'handleExpandToggle'

    handleExpandToggle : (ev) ->
      @trigger 'points:toggle_expanded', @is_expanded
      ev.stopPropagation()

  class Points.UserReasonsPointListFooter extends App.Views.ItemView
    template : '#tpl_points_user_reasons_footer'

    serializeData : ->
      tenant = App.request 'tenant:get'
      params =  
        label : if @options.valence == 'pro' then tenant.getProLabel({capitalize:true}) else tenant.getConLabel({capitalize:true})
        hide_label : "hide_name-#{@options.valence}"
        is_pro : @options.valence == 'pro'
        direction : if @options.valence == 'pro' then 'left' else 'right'
      params

    onShow : ->  
      @$el.find('.newpoint-nutshell').autosize()
      @$el.find('.newpoint-description').autosize()
      @$el.find('.position-statement').autosize()

      for el in @$el.find('.newpoint-form .is_counted')
        $(el).NobleCount $(el).siblings('.count'), 
          block_negative: true,
          max_chars : parseInt $(el).siblings('.count').text()       


    events : 
      'click .newpoint-new' : 'newPoint'
      'click .newpoint-cancel' : 'cancelPoint'
      'click .newpoint-create' : 'createPoint'
      # 'blur .newpoint-nutshell' : 'checkIfShouldClose'
      'focusout .newpoint-form' : 'checkIfShouldClose'

    checkIfShouldClose : (ev) ->
      $form = $(ev.currentTarget).closest('.newpoint-form')

      $nutshell = $form.find('.newpoint-nutshell')
      $description = $form.find('.newpoint-description')

      if $nutshell.val().length + $description.val().length == 0
        click_inside = false
        $form.one 'focusin.checkshouldclose', => 
          click_inside = true

        _.delay =>
          $form.off '.checkshouldclose'
          @cancelPoint(ev) if !click_inside
        , 10

    newPoint : (ev) ->
      $(ev.currentTarget).hide()
      $form = $(ev.currentTarget).siblings('.newpoint-form')

      $form.find('.newpoint-nutshell, .newpoint-description').trigger('keyup')
      $form.show()

      if !Modernizr.input.placeholder
        $form.find('[placeholder]').simplePlaceholder() 
      else
        $form.find('.newpoint-nutshell').focus()

      @$el.find('.newpoint').addClass 'newpoint-adding'
    
    cancelPoint : (ev) ->
      $form = $(ev.currentTarget).closest('.newpoint-form')
      $form.hide()
      $form.siblings('.newpoint-new').show()
      $form.find('textarea').val('').trigger('keydown')
      $form.find('label.inline').addClass('empty')

      @$el.find('.newpoint').removeClass 'newpoint-adding'

    createPoint : (ev) ->
      $form = $(ev.currentTarget).closest('.newpoint-form')

      point_attributes =
        nutshell : $form.find('.newpoint-nutshell').val()
        text : $form.find('.newpoint-description').val()
        is_pro : $form.find('.newpoint-is_pro').val() == 'true'
        hide_name : $form.find('.newpoint-anonymous').is(':checked')
        comment_count : 0

      if point_attributes.nutshell.length < 4
        toastr.error 'Sorry, the summary of your point must be longer'
      else if point_attributes.nutshell.length > 140
        toastr.error 'Sorry, the summary of your point must be less than 140 characters.'
      else
        @trigger 'point:create:requested', point_attributes
        @cancelPoint {currentTarget: $form.find('.newpoint-cancel')}


  class Points.PeerEmptyView extends App.Views.ItemView
    template : '#tpl_points_peer_empty'
    className : 'points_peer_empty'