############################################################
###################### PERMISSIONS #########################
#
# Server permissions
#
# Unfortunately, much of this logic has to be replicated 
# on the client. See 
#         @client/permissions.coffee
# If you're changing the logic
# in one place, you may need to do so in the other as
# well. However, not all server logic needs to be here
# and vice versa.
#


# Permission cases ENUM
# This needs to be synchronized with client (see @client/permissions.coffee).
# Failure cases should be less than 0.
module Permission
  PERMITTED = 1
  DISABLED = -1 # no one can take this action
  UNVERIFIED_EMAIL = -2 # can take action once email is verified 
  NOT_LOGGED_IN = -3 # not sure if action can be taken
  INSUFFICIENT_PRIVILEGES = -4 # we know this user can't do this
end

class PermissionDenied < StandardError
  attr_reader :reason, :key
  def initialize(reason, key = nil)
    @reason = reason
    @key = key
  end
end


def permit(action, object)
  current_user = Thread.current[:current_user]


  def matchEmail(permission_list)
    return true if permission_list.index('*')
    return true if permission_list.index(current_user.key)
    permission_list.each do |email_or_key| 
      if email_or_key.index('*')
        allowed_domain = email_or_key.split('@')[1]
        return true if current_user.email.split('@')[1] == allowed_domain
      end
    end
    return false
  end

  def matchSomeRole(roles, accepted_roles)
    accepted_roles.each do |role|
      return true if matchEmail(roles[role])
    end
    return false
  end

  case action
  when 'create subdomain'
    return Permission::NOT_LOGGED_IN if !current_user.registered

  when 'update subdomain', 'delete subdomain'
    return Permission::NOT_LOGGED_IN if !current_user.registered
    return Permission::INSUFFICIENT_PRIVILEGES if !current_user.is_admin?

  when 'create proposal'
    return Permission::NOT_LOGGED_IN if !current_user.registered
    if !current_user.has_any_role?([:admin, :superadmin, :proposer])
      return Permission::INSUFFICIENT_PRIVILEGES 
    end

  when 'read proposal'
    proposal = object

    if !matchSomeRole(proposal.user_roles, ['editor', 'writer', 'commenter', 'opiner', 'observer'])
      if !current_user.registered
        return Permission::NOT_LOGGED_IN 
      else
        return Permission::INSUFFICIENT_PRIVILEGES 
      end
    elsif !current_user.verified
      return Permission::UNVERIFIED_EMAIL
    end

  when 'update proposal'
    proposal = object

    can_read = permit('read proposal', object)
    return can_read if can_read < 0

    if !current_user.is_admin? && !matchEmail(proposal.user_roles['editors'])
      return Permission::INSUFFICIENT_PRIVILEGES
    end

  when 'delete proposal'
    proposal = object

    can_update = permit('read proposal', object)
    return can_update if can_read < 0

    if !(proposal.opinions.published.count == 0 || (proposal.opinions.published.count == 1 && proposal.opinions.published.first.user_id == current_user.id))
      # don't delete proposal if other people have opined. Might want to reconsider this rule. 
      return Permission::DISABLED
    end

  when 'read opinion'
    opinion = object
    return permit 'read proposal', opinion.proposal

  when 'publish opinion'
    proposal = object
    return Permission::DISABLED if !proposal.active
    if !current_user.is_admin? && !matchSomeRole(proposal.user_roles, ['editor', 'writer', 'opiner'])
      if !current_user.registered
        return Permission::NOT_LOGGED_IN 
      else
        return Permission::INSUFFICIENT_PRIVILEGES
      end
    end

  when 'update opinion', 'delete opinion'
    opinion = object
    
    can_read = permit 'read opinion', opinion
    return can_read if can_read < 0
    return Permission::INSUFFICIENT_PRIVILEGES if current_user.id != opinion.user_id

  when 'read point'
    point = object

    if current_user.id != point.user_id && !current_user.is_admin?
      return Permission::DISABLED if point.published && !(point.moderation_status.nil? || point.moderation_status != 0)
    end

  when 'create point'
    proposal = object
    return Permission::DISABLED if !proposal.active

    if !current_user.is_admin? && !matchSomeRole(proposal.user_roles, ['editor', 'writer'])
      if !current_user.registered
        return Permission::NOT_LOGGED_IN  
      else 
        return Permission::INSUFFICIENT_PRIVILEGES 
      end
    end

  when 'update point'
    point = object
    if !current_user.is_admin? && current_user.id != point.user_id
      return Permission::INSUFFICIENT_PRIVILEGES 
    end

  when 'delete point'
    point = object
    if !current_user.is_admin?
      return Permission::INSUFFICIENT_PRIVILEGES if current_user.id != point.user_id
      return Permission::DISABLED if point.inclusions.count > 1
    end

  when 'read comment'
    comment = object
    return permit('read point', comment.point)

  when 'create comment'
    comment = object
    point = comment.point
    proposal = point.proposal

    return Permission.DISABLED if !proposal.active
    return Permission::NOT_LOGGED_IN if !current_user.registered
  
    if !current_user.is_admin? && !matchSomeRole(proposal.user_roles, ['editor', 'writer', 'commenter'])
      return Permission::INSUFFICIENT_PRIVILEGES
    end

  when 'update comment', 'delete comment'
    comment = object
    can_read = permit 'read comment', comment
    return can_read if can_read < 0

    if !current_user.is_admin? && current_user.id != comment.user_id
      return Permission::INSUFFICIENT_PRIVILEGES 
    end

  when 'request factcheck'
    proposal = object
    return Permission::DISABLED if !proposal.assessment_enabled || !proposal.active
    return Permission::NOT_LOGGED_IN if !current_user.registered 

  when 'factcheck content'
    return Permission::NOT_LOGGED_IN if !current_user.registered
    return Permission::INSUFFICIENT_PRIVILEGES if !current_user.has_any_role?([:admin, :superadmin, :evaluator])

  when 'moderate content'
    return Permission::NOT_LOGGED_IN if !current_user.registered
    return Permission::INSUFFICIENT_PRIVILEGES if !current_user.has_any_role?([:admin, :superadmin, :moderator])
  
  else
    raise "Undefined Permission: #{action}"
  end

  return Permission::PERMITTED
end