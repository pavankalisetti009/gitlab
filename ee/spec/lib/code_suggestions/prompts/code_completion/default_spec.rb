# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::Default, feature_category: :code_suggestions do
  let_it_be(:current_user) { create(:user) }

  subject(:default) { described_class.new({}, current_user) }

  describe '#request_params' do
    it 'returns expected request params' do
      request_params = { prompt_version: 1 }

      expect(default.request_params).to eq(request_params)
    end
  end
end
