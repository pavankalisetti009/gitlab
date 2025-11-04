# frozen_string_literal: true

module API
  module Concerns
    module VirtualRegistries
      module Packages
        module Maven
          module SharedSetup
            extend ActiveSupport::Concern

            included do
              feature_category :virtual_registry
              urgency :low

              after_validation do
                unauthorized! unless ::Feature.enabled?(:maven_virtual_registry, target_group)
                not_found! unless ::Gitlab.config.dependency_proxy.enabled
                not_found! unless target_group.licensed_feature_available?(:packages_virtual_registry)
                not_found! unless ::VirtualRegistries::Setting.find_for_group(target_group).enabled

                authenticate!
              end
            end
          end
        end
      end
    end
  end
end
