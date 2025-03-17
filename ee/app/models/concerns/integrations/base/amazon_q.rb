# frozen_string_literal: true

module Integrations
  module Base
    module AmazonQ
      extend ActiveSupport::Concern

      included do
        validates :role_arn, presence: true, if: :activated?

        field :role_arn, required: true, api_only: true

        attribute :merge_requests_events, default: true
        attribute :pipeline_events, default: true

        attribute :alert_events, default: false
        attribute :commit_events, default: false
        attribute :confidential_issues_events, default: false
        attribute :confidential_note_events, default: false
        attribute :issues_events, default: false
        attribute :job_events, default: false
        attribute :note_events, default: false
        attribute :push_events, default: false
        attribute :tag_push_events, default: false
        attribute :wiki_page_events, default: false
      end

      class_methods do
        def title
          s_('AmazonQ|Amazon Q')
        end

        def description
          s_('AmazonQ|Use GitLab Duo with Amazon Q to create and review merge requests and upgrade Java.')
        end

        def help
          build_help_page_url(
            'user/duo_amazon_q/index.md',
            s_('AmazonQ|Use GitLab Duo with Amazon Q to create and review merge requests and upgrade Java. ' \
              'GitLab Duo with Amazon Q is separate from GitLab Duo Pro and Enterprise.')
          )
        end

        def to_param
          'amazon_q'
        end

        def supported_events
          %w[merge_request pipeline]
        end
      end

      def sections
        [{
          type: 'amazon_q',
          title: s_('AmazonQ|Configure GitLab Duo with Amazon Q'),
          description: help,
          plan: 'ultimate'
        }]
      end

      def editable?
        false
      end

      def manual_activation?
        false
      end

      def execute(data)
        return unless Feature.enabled?(:amazon_q_chat_and_code_suggestions, :instance)

        user = user_from_web_hook_data(data)
        return unless user

        client = ::Gitlab::Llm::QAi::Client.new(user)

        client.create_event(
          payload: { source: :web_hook, data: data },
          role_arn: ::Ai::Setting.instance.amazon_q_role_arn,
          event_id: WebHookService.hook_to_event("#{data[:object_kind]}_hooks")
        )
      end

      private

      def user_from_web_hook_data(data)
        user = ::User.find_by_id(data.dig(:user, :id))
        composite_identity = ::Gitlab::Auth::Identity.fabricate(user)

        return user unless composite_identity&.composite?

        # If a composite identity was propagated through Sidekiq and the user is service account
        # that requires composite identity, we can use the scoped user.
        return unless composite_identity.valid?

        composite_identity.scoped_user
      end
    end
  end
end
