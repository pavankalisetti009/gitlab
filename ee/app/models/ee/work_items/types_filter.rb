# frozen_string_literal: true

module EE
  module WorkItems
    module TypesFilter
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      private

      override :filter_okr
      def filter_okr(types)
        if project_resource_parent? && resource_parent.okrs_mvc_feature_flag_enabled?
          types.union(::WorkItems::TypesFilter::OKR_TYPES)
        else
          super
        end
      end

      override :filter_epic
      def filter_epic(types)
        return types.union(%w[epic]) if epics_enabled?

        super
      end

      def epics_enabled?
        return resource_parent.try(:project_epics_enabled?) if project_resource_parent?

        resource_parent.licensed_feature_available?(:epics)
      end
    end
  end
end
