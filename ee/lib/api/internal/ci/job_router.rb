# frozen_string_literal: true

module API
  module Internal
    module Ci
      class JobRouter < ::API::Base
        feature_category :continuous_integration
        urgency :low

        helpers ::API::Helpers::KasHelpers

        before do
          authenticate_gitlab_kas_request!
        end

        helpers do
          def ensure_job_router_enabled_for_runner!(runner)
            return if Gitlab::Kas.enabled? && job_router_enabled?(runner)

            render_api_error!('Job Router is not available. Please contact your administrator.', 501)
          end

          def ensure_admission_control_enabled_for_runner!(runner)
            return if Feature.enabled?(:job_router_admission_control, runner)

            render_api_error!('Admission Control is not available. Please contact your administrator.', 501)
          end
        end

        namespace 'internal' do
          namespace 'ci' do
            namespace 'job_router' do
              namespace 'runner_controllers' do
                helpers ::API::Ci::Helpers::Runner

                before do
                  authenticate_runner_from_header!
                  Gitlab::ApplicationContext.push(runner: current_runner_from_header)
                end

                desc 'Get applicable runner controllers to use for job admission control' do
                  detail 'Retrieves all applicable runner controller to use for job admission control in the job router'
                  success code: 200
                  failure [
                    { code: 401, message: '401 Unauthorized' },
                    { code: 501, message: '501 Not Implemented' }
                  ]
                  tags %w[jobs job_router]
                end
                get '/job_admission' do
                  ensure_job_router_enabled_for_runner!(current_runner_from_header)
                  ensure_admission_control_enabled_for_runner!(current_runner_from_header)

                  controllers = ::Ci::RunnerController.enabled.select(:id)

                  status 200
                  {
                    runner_controllers: controllers.map { |c| { id: c.id } }
                  }
                end
              end
            end
          end
        end
      end
    end
  end
end
