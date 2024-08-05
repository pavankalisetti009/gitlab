# frozen_string_literal: true

module Types
  module Ai
    module SelfHostedModels
      class AcceptedModelsEnum < BaseEnum
        graphql_name 'AiAcceptedSelfHostedModels'
        description 'LLMs supported by the self-hosted model features.'

        value 'MISTRAL', description: 'Mistral7B model from Mistral AI.', value: 'mistral'
        value 'MIXTRAL', description: 'Mixtral8x22B model from Mistral AI.', value: 'mixtral'
        value 'CODEGEMMA', description: 'CodeGemma 2b or 7b model.', value: 'codegemma'
        value 'CODESTRAL', description: 'Codestral 22B.', value: 'codestral'
        value 'CODELLAMA', description: 'Codellama 13B.', value: 'codellama'
        value 'CODELLAMACODE', description: 'Codellama 13B-code.', value: 'codellama:code'
      end
    end
  end
end
