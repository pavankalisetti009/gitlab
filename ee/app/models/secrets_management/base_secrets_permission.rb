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
    attribute :permissions
    attribute :granted_by, :integer
    attribute :expired_at, :string

    validates :resource, presence: true
    validates :principal_id, :principal_type, presence: true
    validates :permissions, presence: true
    validate :validate_principal_types, :validate_permissions, :validate_role_id
    validate :valid_principal
    validate :validate_expired_at
    validate :ensure_active_secrets_manager

    PRINCIPAL_TYPES = {
      user: 'User',
      role: 'Role',
      group: 'Group',
      member_role: 'MemberRole'
    }.freeze

    PERMISSIONS = {
      read: 'read',
      update: 'update',
      delete: 'delete',
      create: 'create'
    }.freeze

    VALID_PRINCIPAL_TYPES = PRINCIPAL_TYPES.values.freeze
    VALID_PERMISSIONS = PERMISSIONS.values.freeze
    VALID_ROLES = Gitlab::Access.sym_options.except(:guest, :planner).freeze

    delegate :secrets_manager, to: :resource, allow_nil: true

    def normalized_expired_at
      return if expired_at.blank?

      expired_at_to_time.to_s
    end

    def resource_id
      resource.id
    end

    private

    def validate_principal_types
      return if VALID_PRINCIPAL_TYPES.include?(principal_type)

      errors.add(:principal_type, "must be one of: #{VALID_PRINCIPAL_TYPES.join(', ')}")
    end

    def validate_permissions
      permissions&.include?('read') || errors.add(:permissions, 'must include read')

      permissions&.each do |permission|
        next if VALID_PERMISSIONS.include?(permission)

        errors.add(:permissions, "contains invalid permission: #{permission}")
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
      return if resource&.member?(user)

      errors.add(:principal_id, "user is not a member of the #{resource_type.downcase}")
    end

    def valid_group
      principal_group = Group.find_by_id(principal_id)
      return errors.add(:principal_id, "group does not exist") if principal_group.nil?
      return if principal_group_has_access_to_resource?(principal_group)

      errors.add(:principal_id, "group does not have access to this #{resource_type.downcase}")
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
  end
end
