# frozen_string_literal: true

module Groups
  module Settings
    module GitlabDuo
      class ModelSelectionController < Groups::ApplicationController
        feature_category :ai_abstraction_layer

        before_action :check_feature_access!

        def index; end

        private

        def check_feature_access!
          render_404 unless ::Feature.enabled?(:ai_model_switching, associated_group) &&
            associated_group.root? &&
            associated_group.has_owner?(current_user) &&
            associated_group&.namespace_settings&.duo_features_enabled?
        end

        def associated_group
          return @associated_group if defined?(@associated_group)

          @associated_group = group
        end
      end
    end
  end
end
