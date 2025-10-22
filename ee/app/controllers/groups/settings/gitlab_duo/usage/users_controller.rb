# frozen_string_literal: true

module Groups
  module Settings
    module GitlabDuo
      module Usage
        class UsersController < Groups::ApplicationController
          before_action :authorize_read_usage_quotas!
          before_action :ensure_feature_available!

          feature_category :consumables_cost_management

          def show
            @username = params.permit(:username)[:username]
          end

          private

          def ensure_feature_available!
            return render_404 unless Feature.enabled?(:usage_billing_dev, @group)

            render_404 unless Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          end
        end
      end
    end
  end
end
