@ConsiderIt.module "Franklin.Position", (Position, App, Backbone, Marionette, $, _) ->
  class Position.PositionView extends App.Views.ItemView
    template : '#tpl_static_position'
    dialog : ->
      title : "#{@model.getUser().get('name')} #{@model.stanceLabel()} this proposal"

    serializeData : ->
      included_points = @model.getInclusions()
      support_is_pros = @model.get('stance_bucket') >= 3

      _.extend {}, @model.attributes, 
        supporting_points : included_points.where {is_pro : support_is_pros}
        opposing_points : included_points.where {is_pro : !support_is_pros}
        user : @model.getUser().attributes
        stance_label : @model.stanceLabel()