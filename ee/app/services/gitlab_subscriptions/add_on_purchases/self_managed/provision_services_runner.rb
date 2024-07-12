# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      class ProvisionServicesRunner
        SERVICES = [
          ProvisionServices::CodeSuggestions,
          ProvisionServices::DuoEnterprise
        ].freeze

        def execute
          SERVICES.each { |service_class| service_class.new.execute }
        end
      end
    end
  end
end
