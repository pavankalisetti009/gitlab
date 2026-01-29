# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class AdvantagesListComponent < ViewComponent::Base
      private

      delegate :sprite_icon, to: :helpers

      def advantages
        [
          s_('InProductMarketing|Invite unlimited colleagues'),
          s_('InProductMarketing|Free guest users'),
          compliance_advantage,
          s_('InProductMarketing|Built-in security')
        ]
      end

      def compliance_advantage
        if ultimate_trial_with_dap?
          s_('InProductMarketing|Support compliance')
        else
          s_('InProductMarketing|Ensure compliance')
        end
      end

      def heading
        if ultimate_trial_with_dap?
          s_('InProductMarketing|Accelerate delivery with GitLab Ultimate + GitLab Duo Agent Platform')
        else
          s_('InProductMarketing|Experience the power of Ultimate + GitLab Duo Enterprise')
        end
      end

      def ultimate_trial_with_dap?
        Feature.enabled?(:ultimate_trial_with_dap, :instance)
      end
    end
  end
end
