# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    class AddOnTypeEnum < BaseEnum
      graphql_name 'GitlabSubscriptionsAddOnType'
      description 'Types of add-ons'

      value 'CODE_SUGGESTIONS', value: :code_suggestions, description: 'GitLab Duo Pro seat add-on.'
      value 'DUO_ENTERPRISE', value: :duo_enterprise, description: 'GitLab Duo Enterprise seat add-on.'
      value 'DUO_AMAZON_Q', value: :duo_amazon_q, description: 'GitLab Duo with Amazon Q seat add-on.'
    end
  end
end
