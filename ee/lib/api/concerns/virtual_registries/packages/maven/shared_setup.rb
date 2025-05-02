# frozen_string_literal: true

module API
  module Concerns
    module VirtualRegistries
      module Packages
        module Maven
          module SharedSetup
            extend ActiveSupport::Concern
            include ::API::Helpers::Authentication

            included do
              feature_category :virtual_registry
              urgency :low

              authenticate_with do |accept|
                accept.token_types(:personal_access_token).sent_through(:http_private_token_header)
                accept.token_types(:deploy_token).sent_through(:http_deploy_token_header)
                accept.token_types(:job_token).sent_through(:http_job_token_header)
              end

              after_validation do
                unauthorized! unless ::Feature.enabled?(:virtual_registry_maven, current_user)
                not_found! unless ::Gitlab.config.dependency_proxy.enabled
                not_found! unless target_group.licensed_feature_available?(:packages_virtual_registry)

                authenticate!
              end
            end
          end
        end
      end
    end
  end
end
