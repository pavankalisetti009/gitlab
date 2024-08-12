# frozen_string_literal: true

module EE
  module WebIde
    module ExtensionsMarketplace
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override

        override :gallery_disabled_extra_attributes
        def gallery_disabled_extra_attributes(disabled_reason:, user:)
          return enterprise_group_disabled_attributes(user) if disabled_reason == :enterprise_group_disabled

          super
        end

        private

        def enterprise_group_disabled_attributes(user)
          group = user.enterprise_group

          {
            enterprise_group_name: group.full_name,
            enterprise_group_url: ::Gitlab::Routing.url_helpers.group_url(group)
          }
        end
      end
    end
  end
end
