// ...
//= require jquery.fixedheadertable.min
//= require jquery.flot
//= require jquery.flot.selection
//= require moderatable
//= require assessable

$(document)
  .on('click', '.dialog > a', function(){
    var $dialog_window = $(this).parent().children('.detachable');
    $dialog_window.detach().prependTo('#l-wrap > #l-content');
    $dialog_window.data('parent', $(this).parent());
    $dialog_window.show();
  })            
  .on('click', '.detachable a.cancel', function(){
    var $dialog_window = $('#l-wrap > #l-content > .detachable');
    $dialog_window.detach().appendTo($dialog_window.data('parent'));        
    $dialog_window.hide();
  })                  
  .on('ajax:success', '#sharing_settings form', function(data, response, xhr){
    var $dialog_window = $(this).parents('.detachable'),
        $field = $dialog_window.data('parent').children('a').find('span'),
        publicity = response.publicity;

    if (publicity == 2) {
      $field.text('public');          
    } else if (publicity == 1) {
      $field.text('link only');          
    } else if (publicity == 0) {
      $field.text('private');          
    }
    $dialog_window.detach().appendTo($dialog_window.data('parent')).hide();            
  })
  .on('ajax:success', '#status_settings form', function(data, response, xhr){
    var $dialog_window = $(this).parents('.detachable'),
        $field = $dialog_window.data('parent').children('a').find('span'),
        active = response.active;

    $field.text( active ? 'active' : 'inactive');      
    $dialog_window.detach().appendTo($dialog_window.data('parent')).hide();            
  }) 
