# frozen_string_literal: true

module SecretsManagement
  class AuditLog
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    MESSAGES = {
      secrets_manager_read_project_secret: 'Read project secret in CI Pipeline Job',
      secrets_manager_update_project_secret: 'Updated project secret',
      secrets_manager_create_project_secret: 'Created project secret',
      secrets_manager_delete_project_secret: 'Deleted project secret',
      secrets_manager_read_group_secret: 'Read group secret in CI Pipeline Job',
      secrets_manager_update_group_secret: 'Updated group secret',
      secrets_manager_create_group_secret: 'Created group secret',
      secrets_manager_delete_group_secret: 'Deleted group secret'
    }.freeze

    EVENT_TYPE_MAPPING = {
      %w[read project_data] => :secrets_manager_read_project_secret,
      %w[update project_data] => :secrets_manager_update_project_secret,
      %w[create project_data] => :secrets_manager_create_project_secret,
      %w[delete project_metadata] => :secrets_manager_delete_project_secret,
      %w[read group_data] => :secrets_manager_read_group_secret,
      %w[update group_data] => :secrets_manager_update_group_secret,
      %w[create group_data] => :secrets_manager_create_group_secret,
      %w[delete group_metadata] => :secrets_manager_delete_group_secret
    }.freeze

    attribute :raw_audit_log_json
    attribute :parsed_json
    attribute :author
    attribute :project
    attribute :group
    attribute :created_at
    attribute :event_type
    attribute :scope
    attribute :target
    attribute :target_details
    attribute :ip_address
    attribute :message

    def initialize(raw_audit_log_json)
      super()
      self.raw_audit_log_json = raw_audit_log_json
      set_attributes
    end

    def log!
      return unless should_audit?

      ::Gitlab::Audit::Auditor.audit(audit_context)
      true
    rescue StandardError => exception
      Gitlab::ErrorTracking.track_exception(exception)
      false
    end

    private

    def set_attributes
      self.parsed_json = parse_raw_audit_log_json
      self.created_at = DateTime.current
      self.event_type = get_event_type
      self.project = get_project
      self.group = get_group
      self.author = get_author
      self.scope = get_scope
      self.target = get_target
      self.target_details = get_target_details
      self.ip_address = get_ip_address
      self.message = get_message
    rescue StandardError => exception
      Gitlab::ErrorTracking.track_exception(exception)
    end

    def audit_context
      {
        name: event_type,
        author: author,
        scope: scope,
        target: target,
        message: message,
        created_at: created_at,
        ip_address: ip_address,
        additional_details: { raw_audit_log_json: raw_audit_log_json },
        target_details: target_details
      }
    end

    def should_audit?
      !ignore_log? && audit_types_list.include?(event_type.to_sym)
    end

    def ignore_log?
      request_log?
    end

    def audit_types_list
      project_secret_event_types_list.union(group_secret_event_types_list)
    end

    def project_secret_event_types_list
      [
        :secrets_manager_read_project_secret,
        :secrets_manager_create_project_secret,
        :secrets_manager_update_project_secret,
        :secrets_manager_delete_project_secret
      ]
    end

    def group_secret_event_types_list
      [
        :secrets_manager_read_group_secret,
        :secrets_manager_create_group_secret,
        :secrets_manager_update_group_secret,
        :secrets_manager_delete_group_secret
      ]
    end

    def get_author
      extract_user_from_auth_metadata
    end

    def get_scope
      if project_secret_event?
        project
      elsif group_secret_event?
        group
      end
    end

    # Ideally the target should be the ProjectSecret/ GroupSecret, but since ProjectSecret/GroupSecret
    # is not an ActiveRecord model, we are using the Project/Group as the target.
    # because the target must be an ActiveRecord record.
    def get_target
      if project_secret_event?
        project
      elsif group_secret_event?
        group
      end
    end

    def get_target_details
      if project_secret_event?
        "Project: #{project&.full_path}"
      elsif group_secret_event?
        "Group: #{group&.full_path}"
      end
    end

    def get_event_type
      EVENT_TYPE_MAPPING.fetch([operation, path_type], :unknown_event)
    end

    def path_type
      if path_matches_project_secret_data?
        'project_data'
      elsif path_matches_project_secret_metadata?
        'project_metadata'
      elsif path_matches_group_secret_data?
        'group_data'
      elsif path_matches_group_secret_metadata?
        'group_metadata'
      end
    end

    def extract_user_from_auth_metadata
      return unless auth_metadata

      user_id = auth_metadata['user_id'].to_i
      User.find_by(id: user_id)
    end

    def get_project
      return unless namespace_path
      return unless project_secret_event?

      match = namespace_path.match(/project_(\d{1,10})/)
      return unless match

      project_id = match[1]
      Project.find_by(id: project_id)
    end

    def get_group
      return unless namespace_path
      return unless group_secret_event?

      match = namespace_path.match(%r{group_(\d{1,10})/group_\1/})
      return unless match

      group_id = match[1]
      Group.find_by(id: group_id)
    end

    def get_message
      MESSAGES.fetch(event_type, 'Unknown secrets manager event')
    end

    def get_ip_address
      parsed_json.dig('request', 'remote_address')
    end

    def request_path
      parsed_json.dig('request', 'path')
    end

    def namespace_path
      parsed_json.dig('request', 'namespace', 'path')
    end

    def operation
      parsed_json.dig('request', 'operation')
    end

    def auth_metadata
      parsed_json.dig('auth', 'metadata')
    end

    def log_type
      parsed_json['type']
    end

    def project_secret_event?
      event_type.in?(project_secret_event_types_list)
    end

    def group_secret_event?
      event_type.in?(group_secret_event_types_list)
    end

    def path_matches_project_secret_data?
      return false unless namespace_path && request_path

      namespace_path_matches_project_path? && request_path_matches_secret_data?
    end

    def path_matches_project_secret_metadata?
      return false unless namespace_path && request_path

      namespace_path_matches_project_path? && request_path_matches_secret_metadata?
    end

    def path_matches_group_secret_data?
      return false unless namespace_path && request_path

      namespace_path_matches_group_path? && request_path_matches_secret_data?
    end

    def path_matches_group_secret_metadata?
      return false unless namespace_path && request_path

      namespace_path_matches_group_path? && request_path_matches_secret_metadata?
    end

    def request_path_matches_secret_data?
      request_path.match?(%r{\A/?secrets/kv/data/explicit/\w+\z})
    end

    def request_path_matches_secret_metadata?
      request_path.match?(%r{\A/?secrets/kv/metadata/explicit/\w+\z})
    end

    def namespace_path_matches_project_path?
      namespace_path.match?(/project_(\d{1,10})/) && !namespace_path_matches_group_path?
    end

    def namespace_path_matches_group_path?
      namespace_path.match?(%r{group_(\d{1,10})/group_\1/})
    end

    def request_log?
      log_type == 'request'
    end

    def parse_raw_audit_log_json
      return {} if raw_audit_log_json.blank?

      ::Gitlab::Json.parse(raw_audit_log_json)
    end
  end
end
