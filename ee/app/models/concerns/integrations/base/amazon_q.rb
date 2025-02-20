# frozen_string_literal: true

module Integrations
  module Base
    module AmazonQ
      extend ActiveSupport::Concern

      included do
        validates :role_arn, presence: true, if: :activated?

        field :role_arn, required: true, api_only: true
      end

      def execute(_data)
        # currently no-op
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
          []
        end
      end
    end
  end
end
