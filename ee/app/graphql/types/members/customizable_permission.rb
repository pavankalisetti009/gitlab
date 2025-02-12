# frozen_string_literal: true

module Types
  module Members
    module CustomizablePermission
      extend ActiveSupport::Concern

      included do
        # As new custom abilities are created they are implemented behind a feature flag with a standard
        # naming convention. Since these abilities depend on the feature flag being enabled, we want to mark
        # any feature flagged abilities as experimental until they are generally released.
        def self.define_permission(name, attrs)
          if ::Feature::Definition.get("custom_ability_#{name}")
            value name.upcase, value: name, description: attrs[:description],
              experiment: { milestone: attrs[:milestone] }
          else
            value name.upcase, value: name, description: attrs[:description]
          end
        end
      end
    end
  end
end
