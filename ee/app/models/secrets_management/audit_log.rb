# frozen_string_literal: true

module SecretsManagement
  class AuditLog
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    attribute :raw_audit_log_json
    attribute :parsed_json
    attribute :author
    attribute :project
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
      project_secret_event_types_list
    end

    def project_secret_event_types_list
      [
        :secrets_manager_read_project_secret,
        :secrets_manager_create_project_secret,
        :secrets_manager_update_project_secret,
        :secrets_manager_delete_project_secret
      ]
    end

    def get_author
      extract_user_from_auth_metadata
    end

    def get_scope
      return unless project_secret_event?

      project
    end

    # Ideally the target should be the ProjectSecret, but since ProjectSecret
    # is not an ActiveRecord model, we are using the Project as the target.
    # because the target must be an ActiveRecord record.
    def get_target
      return unless project_secret_event?

      project
    end

    def get_target_details
      return unless project_secret_event?

      "Project: #{project&.full_path}"
    end

    def get_event_type
      if operation == 'read' && path_matches_project_secret?
        :secrets_manager_read_project_secret
      elsif operation == 'update' && path_matches_project_secret?
        :secrets_manager_update_project_secret
      elsif operation == 'create' && path_matches_project_secret?
        :secrets_manager_create_project_secret
      elsif operation == 'delete' && path_matches_project_secret_metadata?
        # For delete operation, the Openbao audit log contains only metadata path
        :secrets_manager_delete_project_secret
      else
        :unknown_event
      end
    end

    def extract_user_from_auth_metadata
      return unless auth_metadata

      user_id = auth_metadata['user_id'].to_i
      User.find_by(id: user_id)
    end

    def get_project
      return unless request_path

      return unless project_secret_event?

      match = request_path.match(/project_(\d{1,10})/)
      return unless match

      project_id = match[1]
      Project.find_by(id: project_id)
    end

    def get_message
      if read_project_secret?
        "Read project secret in CI Pipeline Job"
      elsif update_project_secret?
        "Updated project secret"
      elsif create_project_secret?
        "Created project secret"
      elsif delete_project_secret?
        "Deleted project secret"
      else
        "Unknown secrets manager event"
      end
    end

    def get_ip_address
      parsed_json.dig('request', 'remote_address')
    end

    def request_path
      parsed_json.dig('request', 'path')
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

    def read_project_secret?
      event_type == :secrets_manager_read_project_secret
    end

    def update_project_secret?
      event_type == :secrets_manager_update_project_secret
    end

    def create_project_secret?
      event_type == :secrets_manager_create_project_secret
    end

    def delete_project_secret?
      event_type == :secrets_manager_delete_project_secret
    end

    def project_secret_event?
      event_type.in?(project_secret_event_types_list)
    end

    def path_matches_project_secret?
      request_path&.match?(%r{\A.*/project_\d+/secrets/kv/data/explicit/\w+\z})
    end

    def path_matches_project_secret_metadata?
      request_path&.match?(%r{\A.*/project_\d+/secrets/kv/metadata/explicit/\w+\z})
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
