# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Internal
      class UpcomingReconciliations < ::API::Base
        before do
          forbidden!('This API is gitlab.com only!') unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        end

        feature_category :subscription_management
        urgency :low

        namespace :internal do
          namespace :gitlab_subscriptions do
            resource 'namespaces/:namespace_id' do
              params do
                requires :namespace_id, type: Integer, allow_blank: false
              end
              resource :upcoming_reconciliations do
                desc 'Update upcoming reconciliations'
                params do
                  requires :next_reconciliation_date, type: Date
                  requires :display_alert_from, type: Date
                end
                put '/' do
                  upcoming_reconciliations = [
                    {
                      namespace_id: params[:namespace_id],
                      next_reconciliation_date: params[:next_reconciliation_date],
                      display_alert_from: params[:display_alert_from]
                    }
                  ]
                  service = ::UpcomingReconciliations::UpdateService.new(upcoming_reconciliations)
                  response = service.execute

                  if response.success?
                    status 200
                  else
                    render_api_error!({ error: response.errors.first }, 500)
                  end
                end

                desc 'Destroy upcoming reconciliation record'
                delete '/' do
                  upcoming_reconciliation = ::GitlabSubscriptions::UpcomingReconciliation.next(params[:namespace_id])

                  not_found! if upcoming_reconciliation.blank?

                  upcoming_reconciliation.destroy!

                  no_content!
                end
              end
            end
          end
        end
      end
    end
  end
end
