@ConsiderIt.module "Franklin.Proposal", (Proposal, App, Backbone, Marionette, $, _) ->
  
  class Proposal.ProposalDescriptionView extends App.Views.ItemView
    template : '#tpl_proposal_description'
    className : 'm-proposal-description-wrap'

    show_details : true

    editable : =>
      App.request 'auth:can_edit_proposal', @model    

    serializeData : ->
      user_position = @model.getUserPosition()


      user = @model.getUser()
      _.extend {}, @model.attributes,
        proposal : @model
        avatar : App.request('user:avatar', user, 'large' )
        description_detail_fields : @model.description_detail_fields()
        show_details : @show_details
        call : if user_position && user_position.get('published') then 'Update your position' else 'What do you think?'

    initialize : ->
      if @editable()
        if !Proposal.ProposalDescriptionView.editable_fields
          fields = [
            ['.m-proposal-description-title', 'name', 'textarea'], 
            ['.m-proposal-description-body', 'description', 'textarea'] ]

          editable_fields = _.union fields,
            ([".m-proposal-description-detail-field-#{f}", f, 'textarea'] for f in App.request('proposal:description_fields'))          

          Proposal.ProposalDescriptionView.editable_fields = editable_fields

        @editable_fields = Proposal.ProposalDescriptionView.editable_fields

    onRender : ->
      @stickit()
      _.each @editable_fields, (field) =>
        [selector, name, type] = field 

        @$el.find(selector).editable
          resource: 'proposal'
          pk: @long_id
          disabled: @state == 0 && @model.get('published')
          url: Routes.proposal_path @model.long_id
          type: type
          name: name
          success : (response, new_value) => @model.set(name, new_value)

    onShow : ->


    bindings : 
      '.m-proposal-description-title' : 
        observe : ['name', 'description']
        onGet : (values) -> @model.title(280)
      '.m-proposal-description-body' : 
        observe : 'description'
        updateMethod: 'html'
        onGet : (value) => htmlFormat(value)

    events : 
      'click .hidden' : 'showDetails'
      'click .showing' : 'hideDetails'      

    showDetails : (ev) ->
      $block = $(ev.currentTarget).closest('.m-proposal-description-detail-field')

      $toggle = $block.find('.hidden:first')
      
      @desc = $toggle.data('label', $toggle.text()) if !$toggle.data('label')

      $block.find('.m-proposal-description-detail-field-full').slideDown();
      $toggle
        .text('hide')
        .toggleClass('hidden showing');

      ev.stopPropagation()

    hideDetails : (ev) ->
      $block = $(ev.currentTarget).closest('.m-proposal-description-detail-field')

      if $(document).scrollTop() > $block.offset().top
        $('body').animate {scrollTop: $block.offset().top}, 1000

      $toggle = $block.find('.showing:first')

      $block.find('.m-proposal-description-detail-field-full').slideUp(1000);
      $toggle
        .text($toggle.data('label'))
        .toggleClass('hidden showing');

      ev.stopPropagation()
