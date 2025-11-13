# frozen_string_literal: true

module Projects
  module Ci
    class VisualCiEditorController < Projects::ApplicationController
      before_action :check_visual_ci_editor_available!

      feature_category :pipeline_composition

      def show; end

      private

      def check_visual_ci_editor_available!
        render_404 unless Feature.enabled?(:visual_ci_editor, project)
      end
    end
  end
end
