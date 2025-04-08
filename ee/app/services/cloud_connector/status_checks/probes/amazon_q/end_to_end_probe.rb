# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      module AmazonQ
        # Performs a connectivity check request to Amazon Q to verify that
        # GitLab can perform requests to Amazon Q and Amazon Q can perform API requests
        # back to the GitLab instance.
        class EndToEndProbe < BaseProbe
          extend ::Gitlab::Utils::Override

          STATUS_CODE_PASSED = "PASSED"
          STATUS_CODE_FAILED = "FAILED"

          validate :check_user_exists

          def initialize(user)
            @user = user
          end

          def execute
            return failure(failure_message) unless valid?

            verify_oauth_app_probe_results
          end

          private

          attr_reader :user

          def check_user_exists
            errors.add(:base, _('User not provided')) unless user
          end

          def verify_oauth_app_probe_results
            return unless user

            response = ::Gitlab::Llm::QAi::Client.new(user).test_connection
            body = response.parsed_response

            unless response.success?
              message = body&.dig('detail') || _('Unknown error')
              error_msg = format(_("Amazon Q connectivity check failed: %{message}"), message: message)
              return [create_result(false, error_msg)]
            end

            probe_results(body)
          end

          def probe_results(body)
            status_messages = {
              "GITLAB_INSTANCE_REACHABILITY" => _("GitLab instance is reachable by Amazon Q"),
              "GITLAB_CREDENTIAL_VALIDITY" => _("GitLab credentials used by Amazon Q are valid")
            }

            body.filter_map do |check_code, results|
              message = status_messages[check_code]
              next if message.blank?

              case results['status']
              when STATUS_CODE_PASSED
                create_result(true, message)
              when STATUS_CODE_FAILED
                error_msg = format(_("Checking if %{message} failed: %{error}"),
                  message: message, error: results['message'])
                create_result(false, error_msg)
              end
            end
          end
        end
      end
    end
  end
end
