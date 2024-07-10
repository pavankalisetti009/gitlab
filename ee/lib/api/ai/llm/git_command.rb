# frozen_string_literal: true

module API
  module Ai
    module Llm
      class GitCommand < ::API::Base
        feature_category :source_code_management
        urgency :low

        before do
          authenticate!
          check_rate_limit!(:ai_action, scope: [current_user])
        end

        namespace 'ai/llm' do
          desc 'Generates Git commands from natural text'
          params do
            requires :prompt, type: String
          end

          post 'git_command' do
            response = ::Llm::GitCommandService.new(current_user, current_user, declared_params).execute

            if response.success?
              if Feature.enabled?(:move_git_service_to_ai_gateway, current_user)
                response.payload
              else
                config = response.payload

                workhorse_headers = Gitlab::Workhorse.send_url(
                  config[:url],
                  body: config[:body],
                  headers: config[:headers].transform_values { |v| [v] },
                  method: "POST"
                )

                header(*workhorse_headers)
                status :ok
                body ''
              end
            else
              bad_request!(response.message)
            end
          end
        end
      end
    end
  end
end
