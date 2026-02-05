# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module Ultimate
      class TopPageComponent < Trials::TopPageComponent
        extend ::Gitlab::Utils::Override

        private

        override :title
        def title
          if Feature.enabled?(:ultimate_trial_with_dap, :instance)
            s_('Trial|Start your free Ultimate trial')
          else
            s_('Trial|Start your free Ultimate and GitLab Duo Enterprise trial')
          end
        end
      end
    end
  end
end
