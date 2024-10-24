# frozen_string_literal: true

module EE
  module Projects
    module RunnersController
      extend ActiveSupport::Concern

      prepended do
        before_action do
          push_frontend_feature_flag(:gke_runners_ff, project)
        end
      end
    end
  end
end
