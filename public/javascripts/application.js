var ConsiderIt; //global namespace for ConsiderIt js methods

(function($) {

$j = jQuery.noConflict();

ConsiderIt = {
  init : function() {

    ConsiderIt.delegators();
    ConsiderIt.misc.add_tips(); 

    ConsiderIt.per_request();

    $j(document).ajaxComplete(function() {
      ConsiderIt.per_request();
    });    
    
    $j('a.smooth_anchor').click(function(){
      $j('html, body').animate({
        scrollTop: $j($j(this).attr('href')).offset().top}, 1000);
        return false;
    });

    $j("#points_other_pro, #points_other_con").each(function(){
      $j(this).infiniteCarousel({
        speed: 1000,
        vertical: true,
        total_items: parseInt($j(this).find('.total').text()),
        items_per_page: 3,
        loading_from_ajax: true, 
        dim: 600,
        resetSizePerPage: true
      });
    });

    $j('.initiatives.horizontal').infiniteCarousel({
      speed: 1500,
      vertical: false,
      total_items: 6,
      items_per_page: 6,
      loading_from_ajax: false,
      dim: 700    
    });

    ConsiderIt.points.create.initialize_counters('#newpointform-true');
    ConsiderIt.points.create.initialize_counters('#newpointform-false');
    // google analytics
    (function() {
      var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
      ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
      var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
    })();
        
  },
  per_request : function() {
    $j('#masthead').corner('round top 5px');
    $j('#nav-user').corner('bottom bl 5px');  
    $j('.point_in_list_margin').corner('all 5px');
    $j('.avatar').corner('5px');
    $j('input[type="submit"]').corner('5px');
    $j('#registration_form .primary, #registration_form .secondary').corner('8px');
    $j('#pledge_form button').corner('5px');
    $j('#confirmation_sent button#go').corner('5px');
    $j('.newpointform > form').corner('5px');
    $j('.point_link_prompt .button').corner('5px');
    $j('#console').corner('5px');
    $j('#console .nav a').corner('5px');

    $j('.has_example').each(function(){
      $j(this).example($j(this).attr('title')); 
    });
  },

  delegators : function() {

    /////////////
    // ACCOUNTS
    /////////////

    $j(document).delegate('#confirmation_sent button#go', 'click', function(){
        $j('#pledge_dialog').dialog('close');
      });

    $j(document).delegate('#lvg_account a.cancel', 'click', function(){
      $j('.user_dialog').dialog('close');
    });

    $j(document).delegate('#acknowledgment a', 'click', function(){
      show_tos(500, 700);  
    });

    //////////////
    // POINTS
    //////////////

    // new button clicked
    $j('#points').delegate('.newpoint .newpointbutton button', 'click', function(){
      $j(this).parents('.newpoint:first').find('.newpointform').fadeIn('fast');      
      $j('#lightbox').fadeIn('slow');
    });

    // new point cancel clicked
    $j('#points').delegate('.newpoint .newpointform .new_point_cancel', 'click', function(){
      $j(this).parents('.newpointform:first').fadeOut(function(){
        $j('#lightbox').fadeOut();  
      });
    });

    // edit point clicked
    $j('#points').delegate('a.editpoint', 'click', function(){
      $j(this).parents('.edit:first').find('.editpointform').fadeIn('fast');      
      $j('#lightbox').fadeIn('slow');
    });

    // edit point cancel clicked
    $j('#points').delegate('.edit .editform .new_point_cancel', 'click', function(){
      $j(this).parents('.editpointform:first').fadeOut(function(){
        $j('#lightbox').fadeOut();  
      });
    });

    // Create callback
    $j('#points').delegate('.newpoint .newpointform form', 'ajax:success', function(data, response, xhr){
      $j(this).parents('.points_self:first').find('.point_list:first').append(response['new_point']);
      $j(this).find('textarea').val('');
      $j(this).find('.point-title-group .count').html(140);
      $j(this).find('.point-description-group .count').html(500);
      
      $j(this).find('.new_point_cancel').trigger('click');
    });

    // Update callback
    $j('#points').delegate('.editpointform form', 'ajax:success', function(data, response, xhr){
      $j(this).parents('.point_in_list:first').replaceWith(response['new_point']);
      $j('#lightbox').fadeOut();  
    });

    // Delete callback
    $j('#points').delegate('.deletepointform form', 'ajax:success', function(data, response, xhr){
      $j(this).parents('.point_in_list:first').fadeOut();
    });

    // Toggle point details ON
    $j(document).delegate('.point_in_list .toggle.more', 'click', function(){
      var pnt_el_main = $j(this).parents('.point_in_list'),
          pnt_el = pnt_el_main.clone(true, true); // deep clone with cloned events

      var is_pro = pnt_el.hasClass('pro');
      pnt_el.addClass('expanded');

      pnt_el.hide();

      pnt_el.css({
        'z-index': 10000,
        'position': 'absolute'  
      });
      $j('body').append(pnt_el.detach());
      pnt_el.css(pnt_el_main.offset());

      pnt_el.show();

      $j('#lightbox').fadeIn();

      pnt_el_main.css('visibility', 'hidden');
      var animate_properties = { width: '600px' };
      if ( !is_pro ){
        animate_properties['marginLeft'] = -600 + pnt_el.width() + 'px' ;
      }
      pnt_el.animate(animate_properties, function(){
        pnt_el.find('.point_text.full').slideDown(function(){
          pnt_el.find('.avatar').fadeIn();
        });
      });

      pnt_el.find('.toggle.more').fadeOut(function(){pnt_el.find('.less').fadeIn();});

    });
  
    // Toggle point details OFF
    $j(document).delegate('.point_in_list .toggle.less', 'click', function(){
      var pnt_el = $j(this).parents('.point_in_list'),
          pnt_el_main = $j('#' + pnt_el.attr('id') + ':not(.expanded)'),
          is_pro = pnt_el.hasClass('pro'),
          animate_properties = { width: '224px' };
      
      if ( !is_pro ){
        animate_properties['marginLeft'] = '0' ;
      }

      pnt_el.find('.point_text.full').slideUp(function(){
        pnt_el.find('.avatar').fadeOut();
        pnt_el.animate(animate_properties, function(){
          pnt_el.css({
            'z-index': 'inherit',
            'position': 'relative',
            'top': 'auto',
            'left': 'auto',
            'right': 'auto',
            'display': 'block'
          });
          pnt_el_main.replaceWith(pnt_el);          
          pnt_el.removeClass('expanded');

          $j('#lightbox').fadeOut();  

          pnt_el.find('.toggle.less').fadeOut(function(){
            pnt_el.find('.more').fadeIn();
          });

        });
      });

      
    });


    //////////////
    // INCLUSIONS
    //////////////

    // Include in list
    $j(document).delegate('.include .judgepointform form', 'ajax:success', function(data, response, xhr){
      var included_point = $j(this).parents('.point_in_list_margin'), 
      replacement_point = response['new_point'];
    
      if ( included_point.hasClass('pro') ) {
        var user_point_list = $j('#points_self_pro .point_list');
        var other_point_list = $j('#points_other_pro .point_list');
      } else {
        var user_point_list = $j('#points_self_con .point_list');
        var other_point_list = $j('#points_other_con .point_list');
      }
    
      included_point.fadeOut('slow', function() {
        if ( replacement_point ) { 
          included_point.replaceWith(replacement_point);
          ConsiderIt.misc.add_tips(included_point.attr('id'));
        } else {
          included_point.remove();
        }
    
        user_point_list.append(response['approved_point']);
        ConsiderIt.misc.add_tips(user_point_list.attr('id') + '.point_in_list:last');
        //ConsiderIt.points.lists.update_counts(other_point_list, response['pagination']);
      });
    });

    // Remove from list
    $j(document).delegate('.remove .judgepointform form', 'ajax:success', function(data, response, xhr){
      var point_in_margin = response['deleted_point'],
        old_point = $j(this).parents('.point_in_list_self:first');
            
      if ( old_point.hasClass('pro') ) {
        var other_point_list = $j('#points_other_pro .point_list');
      } else {
        var other_point_list = $j('#points_other_con .point_list');
      }
      
      old_point.fadeOut('slow', function(){
        old_point.remove(); 
        other_point_list.append(point_in_margin);
        ConsiderIt.misc.add_tips(other_point_list.attr('id') + '.point_in_list:last');                            
        //ConsiderIt.points.lists.update_counts(new_point_list, judgement, jsoned['pagination']); 
      });  
    });

    //////////////
    //COMMENTS
    //////////////

    // post new comment
    $j(document).delegate('.new_comment form', 'ajax:success', function(data, response, xhr){
        
      var new_point = response['new_point'],
      $parent = $j(this).parents('.comment:first');
      //because we cloned the point in order to show an expanded version when the point in the list 
      // is contained in the carousel, need to add the comment in both places...
      $parent = $j('#' + $parent.attr('id'));
      if($parent.length > 0){
        $parent.find('.comment_children:first').prepend(new_point);
        $j('.new_comment textarea').val("");
        $parent.find('.reply_row a.cancel').trigger('click');
        ConsiderIt.misc.add_tips('#' + parent.attr('id') + ' .comment_children:first .comment:first');
      } else {
        $j(this).parents('.new_comment:first').before(new_point);
        $j(this).find('textarea, .the_subject input').val("");
      }
      
      /*      
      if (grounded_in_point) {
        $j('html, body').animate({
          scrollTop: $j("#comment-" + response['comment_id']).offset().top}, 1000);  
      }*/


    });

  },

  points : {

    lists : {

      update_counts : function(point_list, pagination) {
        var footer = point_list.parent().find('.paginate').parent();
            
        footer.html(pagination);  
      },

      
    },
    
    create : {
      
      positive_count : function( t_obj, char_area, c_settings, char_rem ) {
        ConsiderIt.misc.noblecount.positive_count(t_obj, char_area, c_settings, char_rem, '.newpointform', '.point-submit input' );
      },
      
      negative_count : function( t_obj, char_area, c_settings, char_rem ) {
        ConsiderIt.misc.noblecount.negative_count(t_obj, char_area, c_settings, char_rem, '.newpointform', '.point-submit input' );
      },
      
      initialize_counters : function( form_sel ) {
        var form = $j(form_sel);
            
        var params = {
          on_negative : ConsiderIt.points.create.negative_count,
          on_positive : ConsiderIt.points.create.positive_count,
          block_negative: true,
          max_chars : 140
        };
        
        form.find('.point-title').NobleCount( form_sel + ' .point-title-group .count', params);
        params.max_chars = 700;
        form.find('.point-description').NobleCount( form_sel + ' .point-description-group .count', params);  
      }      
    },
    
  },

  positions : {

    set_slider_value : function(new_value, initiative_name){
        
      var supporting = new_value > 0,
        size = new_value * 50;
      if ( supporting ) {
        $j( '.slider_table .right').css('font-size', 100 + 1.5 * size + '%');
        $j( '.slider_table .left').css('font-size', 100 - size + '%');
      } else {
        $j( '.slider_table .right').css('font-size', 100 + size + '%');
        $j( '.slider_table .left').css('font-size', 100 - 1.5 * size + '%');
      }
      
      $j('#stance-value').val( new_value );  
    },
    
    
    initialize_sliders : function(starting_value, initiative_name, initiative_id){
      var params = { 
        min: -1.0, 
        max: 1.0, 
        value: starting_value, 
        step: .015,
        slide: function(event, ui) {
          $j('.slider').each(function(){
            if ( ui.value != $j(this).slider('value') ) {
              $j(this).slider('value', ui.value)
            }
          });
        },
        change: function(event, ui) {
          value = ui.value
          ConsiderIt.positions.set_slider_value(value, initiative_name);
        },
        stop: function(event, ui){
          data = {
            slider_movement : {
              initiative_id: initiative_id,
              value: ui.value,
              slider_id: $j(this).attr('id').substring(6)  
            }
          };
          
          //$j.post('/study/slider_move', data);
                
        }
        };
        
      $j(".slider").slider(params);
      ConsiderIt.positions.set_slider_value(starting_value, initiative_name);
    },
    
    stance_group_clicked : function(bucket, option_id) {
      //if ( bucket == 'all' ) group_name = 'everyone';
      //else group_name = ConsiderIt.positions.stance_name(bucket);
    
      $j.get("/options/" + option_id + "/points", { bucket: bucket },
        function(data){
          $j('#ranked_points').html(data['points']);
          ConsiderIt.misc.add_tips('#ranked_points');
      } );        
    },
    
    set_stance : function(bucket, dontadjust) {
      if (dontadjust) bucket = parseInt(bucket)
      $j('.stance_name').text(ConsiderIt.positions.stance_name(bucket));
    },
    
    stance_name : function(d) {
      switch (d) {
        case 0: 
          return "strongly oppose"
        case 1: 
          return "oppose"
        case 2:
          return "moderately oppose"
        case 3:
          return "are neutral on"
        case 4:
          return "moderately support"
        case 5:
          return "support"
        case 6:
          return "strongly support"
      }
    }  
    
  },
    
  comments : {
    
    create : {
            
      positive_count : function( t_obj, char_area, c_settings, char_rem ) {
        ConsiderIt.misc.noblecount.negative_count(t_obj, char_area, c_settings, char_rem, '.form', '.comment_submit' );
      },
      
      negative_count : function( t_obj, char_area, c_settings, char_rem ) {
        ConsiderIt.misc.noblecount.negative_count(t_obj, char_area, c_settings, char_rem, '.form', '.comment_submit' );
      },
      
      initialize_counters : function( form_sel ) {
        var form = $j(form_sel);
        
        var params = {
          on_negative : ConsiderIt.comments.create.negative_count,
          on_positive : ConsiderIt.comments.create.positive_count,
          block_negative: true,
          max_chars : 90
        };
        
        form.find('.the_subject input').NobleCount( form_sel + ' .the_subject .count', params);
        params.max_chars = 1000;
        form.find('.body textarea').NobleCount( form_sel + ' .body .count', params);  
      }
      
    },

    set_comment_reply_toggle_events : function(){
      $j('.comment').each(function(){
        var comment_id = $j(this).attr('id').substring(8);
        $j('#comment-'+comment_id+' a.reply:first').click(function(){
          $j('#comment-'+comment_id+' div.reply.hide:first').slideDown(function(){
            $j('#comment-'+comment_id+' a.reply:first').fadeOut();
           });
        });
      
        $j('#comment-'+comment_id+' .new_comment:first a.cancel').click(function(){
          $j('#comment-'+comment_id+' div.reply.hide:first').slideUp(function(){
            $j('#comment-'+ comment_id +' a.reply:first').fadeIn();
           });
        });    
      });
    }
    
  },
  
  misc : {
    add_tips : function( sel ){
      if (!sel) {
        $j('.add_qtip').qtip({ style: { name: 'cream', tip: true }, position: {corner: { target: 'bottomMiddle', tooltip: 'topMiddle' } }});
      } else {
        $j(sel + ' .add_qtip').qtip({ style: { name: 'cream', tip: true }, position: {corner: { target: 'bottomMiddle', tooltip: 'topMiddle' } }});  
      }
    },    
   
    noblecount : {

      positive_count : function( t_obj, char_area, c_settings, char_rem, parent_selector, submit_selector ) {
        var submit_button = t_obj.parents( parent_selector ).find( submit_selector );
        
        if ( char_area.hasClass( 'too_many_chars' ) ) {
          char_area.removeClass( 'too_many_chars' ).css( {
            'font-weight' : 'normal',
            'font-size' : '125%'
          } );
      
          submit_button
              .animate( {
                opacity : 1,
                duration : 50
              } ).attr( 'disabled', false ).css( 'cursor', 'pointer' );
          t_obj.data( 'disabled', false );
        } else if ( char_rem < c_settings.max_chars && $j( t_obj ).data( 'disabled' ) ) {
          t_obj.data( 'disabled', false );
          submit_button
              .attr( 'disabled', false );
        } else if ( char_rem == c_settings.max_chars ) {
          t_obj.data( 'disabled', true );
          submit_button
              .attr( 'disabled', true );
        }
        
      },    
      negative_count : function( t_obj, char_area, c_settings, char_rem, parent_selector, submit_selector ) {
        if ( !char_area.hasClass( 'too_many_chars' ) ) {
          char_area.addClass( 'too_many_chars' ).css( {
            'font-weight' : 'bold',
            'font-size' : '175%'
          } );
      
          t_obj.parents( parent_selector ).find( submit_selector )
              .animate( {
                opacity : .25,
                duration : 50
              } ).attr( 'disabled', true ).css( 'cursor', 'default' );
          t_obj.data( 'disabled', true );
      
        } 
      }
    } 
  }
};

})(jQuery);

// TODO: integrate better into code
// FROM: https://github.com/ryanb/complex-form-examples/blob/master/public/javascripts/application.js
function remove_fields(link) {
  jQuery(link).parents('.point_link_form').remove();
}

function add_fields(link, association, content) {
  var new_id = new Date().getTime();
  var regexp = new RegExp("new_" + association, "g");
  var new_content = content.replace(regexp, new_id);
  jQuery(link).parent().prepend(new_content);
}

function show_tos(width, height) {
  var screenX     = typeof window.screenX != 'undefined' ? window.screenX : window.screenLeft,
      screenY     = typeof window.screenY != 'undefined' ? window.screenY : window.screenTop,
      outerWidth  = typeof window.outerWidth != 'undefined' ? window.outerWidth : document.body.clientWidth,
      outerHeight = typeof window.outerHeight != 'undefined' ? window.outerHeight : (document.body.clientHeight - 22),
      left        = parseInt(screenX + ((outerWidth - width) / 2), 10),
      top         = parseInt(screenY + ((outerHeight - height) / 2.5), 10),
      features    = ('width=' + width + ',height=' + height + ',left=' + left + ',top=' + top);

      var tos = window.open('/home/terms-of-use', 'Terms of Use', features);

  if (tos.focus)
    tos.focus();

  return false;
}

function login(provider_url, width, height) {
  var screenX     = typeof window.screenX != 'undefined' ? window.screenX : window.screenLeft,
      screenY     = typeof window.screenY != 'undefined' ? window.screenY : window.screenTop,
      outerWidth  = typeof window.outerWidth != 'undefined' ? window.outerWidth : document.body.clientWidth,
      outerHeight = typeof window.outerHeight != 'undefined' ? window.outerHeight : (document.body.clientHeight - 22),
      left        = parseInt(screenX + ((outerWidth - width) / 2), 10),
      top         = parseInt(screenY + ((outerHeight - height) / 2.5), 10),
      features    = ('width=' + width + ',height=' + height + ',left=' + left + ',top=' + top);

  newwindow = window.open(provider_url, 'Login', features);

  if (window.focus)
    newwindow.focus();

  return false;
}
