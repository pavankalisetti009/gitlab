# frozen_string_literal: true

module Types
  module Ai
    module SelfHostedModels
      class AcceptedModelsEnum < BaseEnum
        graphql_name 'AiAcceptedSelfHostedModels'
        description 'LLMs supported by the self-hosted model features.'

        value 'CODEGEMMA_2B', 'CodeGemma 2b: Suitable for code completion.', value: 'codegemma_2b'
        value 'CODEGEMMA', 'CodeGemma 7b-it: Suitable for code generation.', value: 'codegemma'
        value 'CODEGEMMA_7B', 'CodeGemma 7b: Suitable for code completion.', value: 'codegemma_7b'
        value 'CODELLAMA_13B_CODE', 'Code-Llama 13b-code: Suitable for code completion.', value: 'codellama_13b_code'
        value 'CODELLAMA', 'Code-Llama 13b: Suitable for code generation.', value: 'codellama'
        value 'CODESTRAL', 'Codestral 22B: Suitable for code completion and code generation.',
          value: 'codestral'
        value 'MISTRAL', 'Mistral 7B: Suitable for code generation and duo chat.', value: 'mistral'
        value 'MIXTRAL_8X22B', 'Mixtral 8x22B: Suitable for code generation and duo chat.', value: 'mixtral_8x22b'
        value 'MIXTRAL', 'Mixtral 8x7B: Suitable for code generation and duo chat.', value: 'mixtral'
        value 'DEEPSEEKCODER', description: 'Deepseek Coder 1.3b, 6.7b and 33b base or instruct.',
          value: 'deepseekcoder'
        value 'MISTRAL_TEXT', description: 'Mistral-7B Text: Suitable for code completion.',
          value: 'mistral_text'
        value 'MIXTRAL_TEXT', description: 'Mixtral-8x7B Text: Suitable for code completion.',
          value: 'mixtral_text'
        value 'MIXTRAL_8X22B_TEXT', description: 'Mixtral-8x22B Text: Suitable for code completion.',
          value: 'mixtral_8x22b_text'
        value 'LLAMA3', description: 'LLaMA 3 - 8B: Suitable for code generation and completion.',
          value: 'llama3'
        value 'LLAMA3_TEXT', description: 'LLaMA 3 Text - 8B: Suitable for code generation and completion.',
          value: 'llama3_text'
        value 'LLAMA3_70B', description: 'LLaMA 3 - 70B: Suitable for code generation and completion.',
          value: 'llama3_70b'
        value 'LLAMA3_70B_TEXT', description: 'LLaMA 3 Text - 70B Text: Suitable for code generation and completion.',
          value: 'llama3_70b_text'
      end
    end
  end
end
