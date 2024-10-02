# frozen_string_literal: true

require 'spec_helper'
require_relative 'ai_gateway_shared_examples'

RSpec.describe CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages, feature_category: :code_suggestions do
  let(:prompt_version) { 3 }

  it_behaves_like 'code generation AI Gateway request prompt' do
    def expected_prompt
      [
        { role: :system, content: system_prompt },
        { role: :user, content: comment },
        { role: :assistant, content: "<new_code>" }
      ]
    end
  end
end
