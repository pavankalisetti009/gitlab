# frozen_string_literal: true

module EE
  module Projects
    module Analytics
      module CycleAnalytics
        module ValueStreamsController
          extend ActiveSupport::Concern
          extend ::Gitlab::Utils::Override

          prepended do
            before_action :load_stage_events, only: %i[new edit]
            before_action :value_stream, only: %i[edit]

            before_action do
              push_frontend_feature_flag(:vsa_standalone_settings_page, project.namespace)
            end
          end
        end
      end
    end
  end
end
