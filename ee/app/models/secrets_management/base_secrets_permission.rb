# frozen_string_literal: true

require 'time'

module SecretsManagement
  class BaseSecretsPermission
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    # group or project the secrets being permitted belong to
    attribute :resource

    # Principal that has the permission (user, role, group)
    attribute :principal_id, :integer
    attribute :principal_type, :string

    # Additional metadata
    attribute :actions
    attribute :granted_by, :integer
    attribute :expired_at, :string

    validates :resource, presence: true
    validates :principal_id, :principal_type, presence: true
    validates :actions, presence: true
    validate :validate_principal_types, :validate_actions, :validate_role_id
    validate :valid_principal
    validate :validate_expired_at
    validate :ensure_active_secrets_manager

    PRINCIPAL_TYPES = {
      user: 'User',
      role: 'Role',
      group: 'Group',
      member_role: 'MemberRole'
    }.freeze

    ACTIONS = {
      read: 'read',
      write: 'write',
      delete: 'delete'
    }.freeze

    # Internal capabilities used in OpenBao
    CAPABILITIES = {
      read: 'read',
      create: 'create',
      update: 'update',
      delete: 'delete',
      list: 'list',
      scan: 'scan'
    }.freeze

    VALID_PRINCIPAL_TYPES = PRINCIPAL_TYPES.values.freeze
    VALID_ACTIONS = ACTIONS.values.freeze
    VALID_CAPABILITIES = CAPABILITIES.values.freeze
    VALID_ROLES = Gitlab::Access.sym_options.except(:guest, :planner).freeze
    MINIMUM_ACCESS_LEVEL = Gitlab::Access::REPORTER

    delegate :secrets_manager, to: :resource, allow_nil: true

    def normalized_expired_at
      return if expired_at.blank?

      expired_at_to_time.to_s
    end

    def resource_id
      resource.id
    end

    # Convert actions to OpenBao capabilities
    # WRITE action maps to both 'create' and 'update' capabilities
    def to_capabilities
      return [] if actions.blank?

      caps = []
      actions.each do |action|
        if action == 'write'
          caps << 'create'
          caps << 'update'
        else
          caps << action
        end
      end
      caps.uniq
    end

    # Convert OpenBao capabilities back to actions
    # If both 'create' and 'update' are present, merge into WRITE action
    def set_actions_from_capabilities(capabilities)
      self.actions = []
      actions << ACTIONS[:read] if capabilities.include?(CAPABILITIES[:read])

      if capabilities.include?(CAPABILITIES[:create]) && capabilities.include?(CAPABILITIES[:update])
        actions << ACTIONS[:write]
      end

      actions << ACTIONS[:delete] if capabilities.include?(CAPABILITIES[:delete])
    end

    private

    def validate_principal_types
      return if VALID_PRINCIPAL_TYPES.include?(principal_type)

      errors.add(:principal_type, "must be one of: #{VALID_PRINCIPAL_TYPES.join(', ')}")
    end

    def validate_actions
      actions&.include?('read') || errors.add(:actions, 'must include read')

      actions&.each do |action|
        next if VALID_ACTIONS.include?(action)

        errors.add(:actions, "contains invalid action: #{action}")
      end
    end

    def validate_role_id
      return unless principal_type == 'Role' && VALID_ROLES.values.exclude?(principal_id)

      valid_role_names = VALID_ROLES.map { |name, value| "#{name} (#{value})" }.join(', ')
      errors.add(:principal_id, "must be one of: #{valid_role_names}")
    end

    def expired_at_to_time
      Time.zone.parse(expired_at)&.utc&.iso8601
    rescue ArgumentError
      nil
    end

    def expired?
      time = expired_at_to_time
      time.present? && Time.current >= time
    end

    def validate_expired_at
      return if expired_at.blank?

      unless expired_at_to_time
        errors.add(:expired_at, 'invalid time format, must be RFC3339 (e.g., 2025-09-01T00:00:00Z)')

        return
      end

      return unless expired?

      errors.add(:expired_at, 'must be in the future')
    end

    def valid_principal
      return if principal_type == 'Role'

      case principal_type
      when 'User'
        valid_user
      when 'Group'
        valid_group
      when 'MemberRole'
        valid_member_role
      end
    end

    def valid_user
      user = User.find_by_id(principal_id)
      return errors.add(:principal_id, "user does not exist") if user.nil?

      member = resource&.members&.find_by(user_id: user.id)
      return errors.add(:principal_id, "user is not a member of the #{resource_type.downcase}") if member.nil?

      return unless member.access_level < MINIMUM_ACCESS_LEVEL

      errors.add(:principal_id, "user must have at least Reporter role")
    end

    def valid_group
      principal_group = Group.find_by_id(principal_id)
      return errors.add(:principal_id, "group does not exist") if principal_group.nil?

      unless principal_group_has_access_to_resource?(principal_group)
        return errors.add(:principal_id,
          "group does not have access to this #{resource_type.downcase}")
      end

      group_link = find_group_link(principal_group)
      return unless group_link && group_link.group_access < MINIMUM_ACCESS_LEVEL

      errors.add(:principal_id, "group must have at least Reporter role")
    end

    def valid_member_role
      member_role = MemberRole.find_by_id(principal_id)
      return errors.add(:principal_id, "Member Role does not exist") if member_role.nil?
      return if member_role_has_access_to_resource?(member_role)

      errors.add(:principal_id, "Member Role does not have access to this #{resource_type.downcase}")
    end

    def ensure_active_secrets_manager
      errors.add(:base, "#{resource_type} secrets manager is not active.") unless secrets_manager&.active?
    end

    def resource_type
      raise NotImplementedError
    end

    def principal_group_has_access_to_resource?(principal_group)
      raise NotImplementedError
    end

    def member_role_has_access_to_resource?(member_role)
      raise NotImplementedError
    end

    def find_group_link(principal_group)
      raise NotImplementedError
    end
  end
end
