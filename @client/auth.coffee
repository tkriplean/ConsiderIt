Auth = ReactiveComponent
  displayName: 'Auth'

  render: -> 
    current_user = fetch('/current_user')
    subdomain = fetch('/subdomain')
    root = fetch('root')

    # When we switch to new auth_mode screens, wipe out all the old
    # errors, cause we're startin' fresh!
    if not @local.last_auth_mode or @local.last_auth_mode != root.auth_mode
      @local.last_auth_mode = root.auth_mode
      current_user.errors = []


    # Let's set up some useful helpers
    submitOnEnter = (event) =>
      if event.which == 13
        event.preventDefault()
        @submitAuth(event)

    input_box = (name, placeholder, type, onChange, pattern) =>
      if @local[name] != current_user[name]
        @local[name] = current_user[name]
        save @local

      # There is a react bug where input cursor will jump to end for 
      # controlled components. http://searler.github.io/react.js/2014/04/11/React-controlled-text.html
      # This makes it annoying to edit text. I've contained this issue to edit_profile only
      # by only setting value in the Input component when in edit_profile mode
      type = type || 'text'
      onChange = onChange || (event) => 
        @local[name] = current_user[name] = event.target.value
        save @local

      INPUT
        id: 'user_' + name
        value: if @root.auth_mode == 'update' then @local[name] else null
        name: "user[#{name}]"
        key: "#{name}_input_box"
        placeholder: placeholder
        required: "required"
        type: type
        onChange: onChange
        onKeyPress: submitOnEnter
        pattern: pattern

    name_input_field     = input_box('name', 'first and last name')
    email_input_field    = input_box('email', 'email@address', 'email')

    password_input_field =
      input_box('password',
                 if root.auth_mode == 'login' then "password" else if root.auth_mode == 'register' then 'choose a password' else "choose a new password",
                 'password',
                 null,
                 if root.auth_mode == 'register' then ".{5,}" else '')

    providers = ['facebook', 'google']

    third_party_authenticated = current_user.facebook_uid || current_user.twitter_uid || current_user.google_uid

    #####
    # We used to display the Auth header using the position and
    # styling of the slider.  Now it's just neutral.

    # Asset fingerprinting. This is why this file is ERB
    bubblemouth_src = "<%= asset_path 'bubblemouth_neutral-crafting.png' %>"

    bubble_mouth_props = 
      transform: "translate(0px, 11px) scale(1.5, 1.5)"
      left: 270
      position: 'relative'
    css.crossbrowserify bubble_mouth_props

    if !subdomain.has_civility_pledge
      pledges = []
    else
      pledges = ['I will participate with only one account', 
                 'I will speak only on behalf of myself', 
                 'I will not attack or mock others']

    auth_area_style = 
      padding: '1.5em 18px .5em 18px'
      fontSize: 21
      marginTop: 10

    if @root.auth_mode != 'update'
      _.extend auth_area_style, 
        borderRadius: 16
        borderStyle: 'dashed'
        borderWidth: 3
        borderColor: considerit_blue

    DIV null,
      if @root.auth_mode == 'update'
        DashHeader name: 'Edit Profile'

      DIV
        style: 
          margin: '0 auto 10em 0'
          position: 'relative'
          display: 'block'
          zIndex: 0
          margin: 'auto'
          marginLeft: if lefty then 300
          position: 'relative'
          width: DECISION_BOARD_WIDTH

        onClick: (e) => e.stopPropagation()

        if @root.auth_mode != 'update'
          DIV 
            className: 'auth_header'
            style : 
              width: HISTOGRAM_WIDTH
              position: 'relative'
              margin: 'auto' 
              top: 5
            DIV 
              className:'auth_heading'
              style: 
                borderRadius: 10                
                fontWeight: 700
                color: considerit_blue
                textAlign: 'center'
                visibility: 'visible'
                left: HISTOGRAM_WIDTH / 2.0
                top: 5
                marginLeft: -225
                width: 450
                fontSize: 50
                position: 'relative'

              'Introduce Yourself' 
              if @root.auth_reason
                DIV style: {fontSize: 18, margin: '-8px 0 15px 0'},
                  "To #{@root.auth_reason}"

            DIV 
              className: 'the_handle'
              style: 
                left: 255
                height: SLIDER_HANDLE_SIZE * 2.5
                width: SLIDER_HANDLE_SIZE * 2.5
                top: 0
                borderRadius: '50%'
                marginLeft: -SLIDER_HANDLE_SIZE / 2
                backgroundColor: considerit_blue
                position: 'relative'
                boxShadow: "0px 1px 0px black, inset 0 1px 2px rgba(255,255,255, .4), 0px 0px 0px 1px #{considerit_blue}"

            IMG className:'bubblemouth', src: bubblemouth_src, style: bubble_mouth_props

        DIV 
          className: "auth" + (if @local.submitting then ' waiting' else '')
          style: auth_area_style
          if root.auth_mode in ['login', 'register'] && !current_user.provider && !third_party_authenticated
            DIV className: 'third_party_auth',
              LABEL 
                style: {marginRight: 18}
                'Instantly:'
              for provider in providers
                do (provider) =>
                  BUTTON key: provider, className: "third_party_option #{provider}", onClick: (=> @startThirdPartyAuth(provider)),
                    I className: "fa fa-#{provider}"
                    SPAN null, provider

              DIV 
                style: 
                  fontWeight: 700
                  paddingTop: '1em'
                  color: "rgba(36,120,204,0.1)"
                dangerouslySetInnerHTML:{__html: "&mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash;  <label style=\"padding: 0 18px; color: #{considerit_blue}\">or</label>  &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash; &mdash;"}

          if root.auth_mode in ['login', 'login_via_reset_password_token', 'verify']
            DIV null, 
              if root.auth_mode == 'login'
                LABEL 
                  style: 
                    padding: '1em 0'
                    display: 'block'
                  'By email address:'
              else if root.auth_mode == 'login_via_reset_password_token'
                DIV null,
                  LABEL className: 'reset_password_section_label', 'Reset your password'
                  DIV style: {'margin-bottom': 16}, "We just sent you a verification code via email to #{current_user.email}. Check your email, and enter the code here:"
              else if root.auth_mode == 'verify'
                DIV null,
                  LABEL className: 'reset_password_section_label', 'Confirm your email address'
                  DIV style: {'margin-bottom': 16}, 
                    "Hi! For additional security, we require users to prove that they control the email address with which they’re accessing this private area." 
                  DIV style: {'margin-bottom': 16},
                    "We just sent a verification code via email to #{current_user.email}. Check your email, and enter the code here:"


              TABLE className: 'auth_fields login',
                TBODY null,
                  if root.auth_mode in ['login_via_reset_password_token', 'verify']
                    TR null, 
                      TD className: 'label_cell', 
                        LABEL htmlFor: 'user_verification_code', 'code:'

                      TD className: 'field_cell', 
                        INPUT
                          id: "verification_code"
                          name: "verification_code"
                          key: "reset_password_token_input_box"
                          placeholder: "verification code"
                          required: "required"
                          type: "text"
                          onKeyPress: submitOnEnter
                          onChange: (event) => current_user.verification_code = event.target.value
                        DIV 
                          style: {fontSize: 12}
                          "Find code in an email just sent to you."

                  else
                    TR null,
                      TD className: 'label_cell',
                        LABEL htmlFor: 'user_email', 'email:'
                      TD className: 'field_cell',
                        email_input_field

                  if root.auth_mode in ['login_via_reset_password_token', 'login']
                    TR null,
                      TD {style: (if root.auth_mode == 'login_via_reset_password_token' then {width: '37%'} else {}), className: 'label_cell'},
                        LABEL htmlFor: 'user_password', "#{if root.auth_mode == 'login_via_reset_password_token' then 'new ' else ''}password:"

                      TD className: 'field_cell', 
                        password_input_field,
                        if root.auth_mode == 'login'
                          A 
                            onClick: @sendResetPassword
                            style: 
                              fontSize: 11
                              borderBottom: '1px solid #ccc'
                              color: '#888'
                              marginLeft: 12
                              position: 'relative'
                              top: -4
                            'I forgot! Email me password instructions.'


          else 
            # creating new account
            TABLE className: 'auth_fields register', 
              TBODY null,
                TR null, 
                  TD className: 'label_cell',
                    LABEL htmlFor: 'user_name', 'Hi, my name is:'
                  TD className: 'field_cell', 
                    name_input_field

                if third_party_authenticated && @root.auth_mode != 'update'
                  p = if current_user.google_uid then 'google' else if current_user.facebook_uid then 'facebook' else 'twitter'
                  TR null, 

                    TD className: 'label_cell',
                      LABEL htmlFor: 'user_provider', 
                        if third_party_authenticated then 'I login via:' else 'I login as:'
                    TD className: 'field_cell', 
                      BUTTON className: "third_party_option #{p}", style: {cursor: 'default'},
                        I className: "fa fa-#{p}"
                        SPAN null, p

                else

                  TR null, 

                    TD className: 'label_cell',
                      LABEL htmlFor: 'user_email', 'I login as:'
                    TD className: 'field_cell', 
                      if !Modernizr.input.placeholder
                        LABEL htmlFor: 'user_email', 'Email:'
                      if root.auth_mode == 'register-after-invite'
                        current_user.email
                      else
                        email_input_field

                      if !Modernizr.input.placeholder
                        LABEL htmlFor: 'user_password', 'Password:'
                      password_input_field

                # We're not going to bother with letting IE9 users set a profile picture. Too much hassle. 
                if window.FormData

                  TR null, 
                    TD className: 'label_cell', 
                      LABEL htmlFor: 'user_avatar', 'I look like this:'
                    TD className: 'field_cell',
                      # hack for submitting file data in ActiveREST for now
                      # we'll just submit the file form after user is signed in


                      FORM 
                        id: 'user_avatar_form'
                        action: '/update_user_avatar_hack', 

                        DIV className: 'avatar_preview_enclosure',
                          IMG id: 'avatar_preview', src: if current_user.avatar_remote_url then current_user.avatar_remote_url else if current_user.b64_thumbnail then current_user.b64_thumbnail else null

                        INPUT 
                          id: 'user_avatar'
                          name: "avatar"
                          type: "file"
                          style: {marginTop: 24, verticalAlign: 'top'}
                          onChange: (ev) => 
                            @submit_avatar_form = true
                            input = $('#user_avatar')[0]
                            if input.files && input.files[0]
                              reader = new FileReader()
                              reader.onload = (e) ->
                                $("#avatar_preview").attr 'src', e.target.result
                              reader.readAsDataURL input.files[0]
                              #current_user.avatar = input.files[0]
                            else
                              $("#avatar_preview").attr('src', "<%= asset_path 'no_image_preview.png' %>")

                if subdomain.has_civility_pledge && root.auth_mode != 'update'
                  TR null,
                    TD className: 'label_cell', 
                      LABEL null, 'Community pledge:'
                    TD className: 'field_cell',
                      UL className: 'pledges',
                        for pledge, idx in pledges
                          LI 
                            className: 'pledge'
                            style: {listStyle: 'none'} 
                            INPUT 
                              className:"pledge-input"
                              type:'checkbox'
                              id:"pledge-#{idx}"
                              name:"pledge-#{idx}"
                              style: {fontSize: 21}
                            LABEL 
                              htmlFor: "pledge-#{idx}"
                              style: 
                                fontSize: 14
                                color: '#414141'
                                paddingLeft: 6
                                fontWeight: 400
                              pledge

          if current_user.errors && current_user.errors.length > 0
            DIV
              style: 
                textAlign: 'center'
                fontSize: 21
                color: 'darkred'
                backgroundColor: '#ffD8D8' 
                padding: 10
              I 
                className: 'fa fa-exclamation-circle'
                style: {paddingRight: 9}
              SPAN null, "#{current_user.errors.join(', ')}"

          if root.auth_mode in ['login', 'register']
            toggle_auth = A 
                      style: 
                        display: 'inline-block'
                        color: considerit_blue
                        textDecoration: 'underline'
                        backgroundColor: 'transparent'
                        border: 'none'
                        fontWeight: 600
                      onClick: => 
                        current_user = fetch('/current_user')
                        @root.auth_mode = if @root.auth_mode == 'register' then 'login' else 'register'
                        current_user.errors = []
                        save(@root)                      
                      if root.auth_mode == 'register'
                        'Use an Existing Account' 
                      else 
                        'Create an Account'

            DIV 
              style: 
                fontSize: 20
                left: 0
                position: 'relative'
                top: -6
                fontWeight: 'normal'
                marginTop: 20
                backgroundColor: '#ffffa1'
                padding: 14
              SPAN null,
                if root.auth_mode == 'register'
                  ['Or ', toggle_auth, ' if you have one already']
                else
                  ['Or ', toggle_auth, ' if you need one']

        DIV null, 
          DIV
            className:'auth_button primary_button' + (if @local.submitting then ' disabled' else '')
            onClick: @submitAuth
            if root.auth_mode == 'register'
              'Create account' 
            else if root.auth_mode == 'register-after-invite'
              'Complete registration'
            else if root.auth_mode == 'update'
              'Update'
            else 
              'Login'
            if root.auth_reason == 'Save your Opinion' then ' and save your opinion'

          if root.auth_mode == 'update'
            if @local.saved_successfully
              SPAN style: {color: 'green'}, "Updated successfully"
          else
            A 
              className:'cancel_auth_button primary_cancel_button'
              onClick: =>
                if root.auth_mode == 'verify'
                  window.app_router.navigate("/", {trigger: true})
                root.auth_mode = null
                save root
              'cancel log in'

  componentDidMount : -> 
    if $(@getDOMNode()).find('.auth_heading').length > 0
      $(document).scrollTop $(@getDOMNode()).find('.auth_heading').offset().top - 10

    window.writeToLog
      what: 'accessed authentication'

  startThirdPartyAuth : (provider) ->
    root = @root
    new ThirdPartyAuthHandler
      provider : provider
      callback : (new_data) => 
        # Yay we got a new current_user object!  But this hasn't gone
        # through the normal arest channel, so we gotta save it in
        # sneakily with updateCache()
        arest.updateCache(new_data)

        # We know that the user has authenticated, but we don't know
        # whether they've completed OUR registration process including
        # the pledge.  The server tells us this via the existence of a
        # `user' object in current_user.

        current_user = fetch '/current_user'
        if current_user.logged_in
          # We are logged in!  The user has completed registration.
          @authCompleted()

        else 
          # We still need to show the pledge!
          root.auth_mode = 'register'
          save(root)

  submitAuth : (ev) -> 
    ev.preventDefault()
    $el = $(@getDOMNode())

    @local.submitting = true
    save @local

    current_user = fetch('/current_user')

    current_user.signed_pledge = $el.find('.pledge-input').length == $el.find('.pledge-input:checked').length
    current_user.trying_to = @root.auth_mode
    
    save current_user, => 
      if @root.auth_mode in ['register', 'update']
        ensureCurrentUserAvatar()

      if @root.auth_mode == 'update'
        @local.saved_successfully = current_user.errors.length == 0        

      # Once the user logs in, we will stop showing the log-in screen
      else if current_user.logged_in
        @authCompleted()

      @local.submitting = false
      save @local

    # hack for submitting file data in ActiveREST for now
    # we'll just submit the file form after user is signed in
    # TODO: investigate alternatives for submitting form data
    if @submit_avatar_form

      $('#user_avatar_form').ajaxSubmit
        type: 'PUT'
        data: 
          authenticity_token: current_user.csrf
          trying_to: 'update_avatar_hack'


  sendResetPassword : -> 

    # Tell the server to email us a token
    current_user = fetch('/current_user')
    current_user.trying_to = 'send_password_reset_token'
    save current_user, =>
      if not (current_user.errors?.length > 0)
        # Switch to reset_password mode
        @root.auth_mode = 'login_via_reset_password_token'
        save(@root)
      else
        # console.log("Waiting for user to fix errors #{current_user.errors?}")
        arest.updateCache(current_user)
      
  authCompleted : -> 

    if @root.auth_reason == 'Save your Opinion'
      setTimeout((() -> togglePage('results', 'after_save')), 700)

    @root.auth_mode = @root.auth_reason = null

    save @root

styles += """
.auth .third_party_option {
  border: 1px solid #777777;
  border-color: rgba(0, 0, 0, 0.2);
  border-bottom-color: rgba(0, 0, 0, 0.4);
  color: white;
  box-shadow: inset 0 0.1em 0 rgba(255, 255, 255, 0.4), inset 0 0 0.1em rgba(255, 255, 255, 0.9);
  display: inline-block;
  padding: 3px 9px 3px 34px;
  margin: 0 4px;
  text-align: center;
  text-shadow: 0 1px 0 rgba(0, 0, 0, 0.5);
  border-radius: 0.3em;
  position: relative;
  background-color: #{considerit_blue}; }
  .auth .third_party_option:hover {
    background-color: #19528b; }
  .auth .third_party_option:before {
    border-right: 0.075em solid rgba(0, 0, 0, 0.1);
    box-shadow: 0.075em 0 0 rgba(255, 255, 255, 0.25);
    content: "";
    position: absolute;
    top: 0;
    left: 25px;
    height: 100%;
    width: 1px; }
  .auth .third_party_option i {
    margin-right: 18px;
    display: inline-block;
    font-size: 16px;
    position: absolute;
    left: 9px; }
  .auth .third_party_option span {
    font-weight: 600;
    font-size: 12px; }
.auth .reset_password_section_label {
  padding: 0 0 1em 0;
  display: block; }
.auth input[type="text"], .auth input[type="email"], .auth input[type="password"] {
  border: 1px solid #aaaaaa;
  padding: 5px 10px;
  width: 100%;
  font-size: 18px;
  color: #414141; }
.auth table {
  border-collapse: separate; }
  .auth table.login {
    border-spacing: 0 0.25em; }
  .auth table.register {
    border-spacing: 0 1em; }
    .auth table.register #user_password {
      margin-top: 0.5em; }
.auth td {
  vertical-align: top; }
  .auth td.label_cell {
    width: 37%; }
  .auth td.field_cell {
    width: 100%;
    padding-left: 18px; }
.auth label {
  color: #{considerit_blue};
  font-weight: 600; }
.auth .login label {
  color: #595959; }

.avatar_preview_enclosure {
  height: 60px;
  width: 60px;
  border-radius: 50%;
  background-color: #e6e6e6;
  overflow: hidden;
  display: inline-block;
  margin-right: 18px; }
  .avatar_preview_enclosure #avatar_preview {
    width: 60px; }

"""



class ThirdPartyAuthHandler 
  constructor : (options = {}) ->
    provider = options.provider
    callback = options.callback

    if provider == 'google'
      provider = 'google_oauth2'
      
    vanity_url = location.host.split('.').length == 1
    if !vanity_url
      document.domain = location.host.replace(/^.*?([^.]+\.[^.]+)$/g,'$1') 
    else 
      document.domain = document.domain # make sure it is explitly set

    @callback = callback
    @popup = @openPopupWindow "/auth/#{provider}"

  pollLoginPopup : ->
    # try
    if @popup? && @popup.document && window.document && window.document.domain == @popup.document.domain && @popup.current_user_hash?
      @callback @popup.current_user_hash
      @popup.close()
      @popup = null
      clearInterval(@polling_interval)
    # catch e
    #   console.error e

  openPopupWindow : (url) ->
    openidpopup = window.open(url, 'openid_popup', 'width=450,height=500,location=1,status=1,resizable=yes')
    openidpopup.current_user_hash = null
    coords = @getCenteredCoords(450,500)  
    openidpopup.moveTo(coords[0],coords[1])
    @polling_interval = setInterval => 
      @pollLoginPopup()
    , 200

    openidpopup

  getCenteredCoords : (width, height) ->
    if (window.ActiveXObject)
      xPos = window.event.screenX - (width/2) + 100
      yPos = window.event.screenY - (height/2) - 100
    else
      parentSize = [window.outerWidth, window.outerHeight]
      parentPos = [window.screenX, window.screenY]
      xPos = parentPos[0] +
          Math.max(0, Math.floor((parentSize[0] - width) / 2))
      yPos = parentPos[1] +
          Math.max(0, Math.floor((parentSize[1] - (height*1.25)) / 2))
    yPos = 100
    [xPos, yPos]

window.ThirdPartyAuthHandler = ThirdPartyAuthHandler
window.Auth = Auth
