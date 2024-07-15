# frozen_string_literal: true

module API
  class Chat < ::API::Base
    include APIGuard

    feature_category :duo_chat

    allow_access_with_scope :ai_features

    AVAILABLE_RESOURCES = %w[issue epic group project merge_request].freeze

    before do
      authenticate!

      not_found! unless Feature.enabled?(:access_rest_chat, current_user)
    end

    helpers do
      def user_allowed?(resource)
        current_user.can?("read_#{resource.to_ability_name}", resource) &&
          Llm::ChatService.new(current_user, resource).valid?
      end

      def find_resource(parameters)
        return current_user unless parameters[:resource_type] && parameters[:resource_id]

        object = parameters[:resource_type].camelize.safe_constantize
        object.find(parameters[:resource_id])
      end
    end

    namespace 'chat' do
      resources :completions do
        params do
          requires :content, type: String, limit: 1000, desc: 'Prompt from user'
          optional :resource_type, type: String, limit: 100, values: AVAILABLE_RESOURCES, desc: 'Resource type'
          optional :resource_id, type: Integer, desc: 'ID of resource.'
          optional :referer_url, type: String, limit: 1000, desc: 'Referer URL'
          optional :client_subscription_id, type: String, limit: 500, desc: 'Client Subscription ID'
          optional :with_clean_history, type: Boolean,
            desc: 'Indicates if we need to reset the history before and after the request'
        end
        post do
          safe_params = declared_params(include_missing: false)
          resource = find_resource(safe_params)

          not_found! unless user_allowed?(resource)

          ai_response = ::Gitlab::Duo::Chat::Completions.new(current_user, resource: resource)
                                                        .execute(safe_params: safe_params)

          present ai_response.response_body
        end
      end
    end
  end
end
