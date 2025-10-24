# frozen_string_literal: true

module API
  # Internal API for Openbao to interact with
  # Gitlab application for the Gitlab Secrets Manager feature.
  module Internal
    class SecretsManager < ::API::Base
      feature_category :secrets_management
      MAX_REQUEST_PAYLOAD_SIZE = 1.megabyte

      before do
        validate_request!
        authenticate_request_from_openbao!
      end

      helpers do
        include ::Gitlab::Utils::StrongMemoize

        def validate_request!
          # Limit request body size to prevent DoS
          if request.content_type == 'application/json' && request.content_length &&
              request.content_length.to_i < MAX_REQUEST_PAYLOAD_SIZE
            return
          end

          render_api_error!('Invalid content type', :bad_request)
        end

        def authenticate_request_from_openbao!
          return if openbao_authentication_token_secret == authentication_token_from_header

          render_api_error!('Unauthorized', :unauthorized)
        end

        def openbao_authentication_token_secret
          # Prevent symlink-based path traversal attacks.
          file_path = openbao_authentication_token_secret_file_path
          root_path = Rails.root.realpath.to_s + File::SEPARATOR
          real_path = Pathname.new(file_path).realpath.to_s
          raise "Invalid authentication token file path" unless real_path.start_with?(root_path)
          raise "Authentication token path is not a file" unless File.file?(real_path)

          token_secret = File.read(real_path).chomp
          raise "Empty Openbao authentication token secret" if token_secret.empty?

          token_secret
        rescue Errno::ENOENT, Errno::EACCES => e
          Gitlab::ErrorTracking.track_exception(e)
          raise "Unable to fetch Openbao authentication token secret"
        end
        strong_memoize_attr :openbao_authentication_token_secret

        def openbao_authentication_token_secret_file_path
          Gitlab.config.openbao['authentication_token_secret_file_path']
        end

        def authentication_token_from_header
          headers['Gitlab-Openbao-Auth-Token']
        end
      end

      namespace 'internal' do
        namespace 'secrets_manager' do
          resource :audit_logs do
            desc 'Instrument a new audit log' do
              detail 'Creates a new audit log entry for an action performed in Openbao.'
              tags 'secrets_manager'
              success code: 202
            end
            post do
              raw_audit_log_json = request.body.read
              audit_log = SecretsManagement::AuditLog.new(raw_audit_log_json)
              audit_log.log!

              accepted!
            end
          end
        end
      end
    end
  end
end
