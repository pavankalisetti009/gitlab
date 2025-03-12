# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Templates::DescriptionComposer, feature_category: :code_review_workflow do
  let_it_be(:merge_request) { create(:merge_request) }

  let(:params) do
    {
      description: 'Client merge request description',
      user_prompt: 'Hello world from user prompt'
    }
  end

  subject(:template) { described_class.new(merge_request, params) }

  describe '#to_prompt' do
    it 'includes raw diff' do
      diff_file = merge_request.raw_diffs.to_a[0]

      expect(template.to_prompt[:messages][0][:content]).to include(diff_file.diff.split("\n")[1])
    end

    it 'includes merge request title' do
      expect(template.to_prompt[:messages][0][:content]).to include(merge_request.title)
    end

    it 'includes user prompt' do
      expect(template.to_prompt[:messages][0][:content]).to include('Hello world from user prompt')
    end

    it 'includes description sent from client' do
      expect(template.to_prompt[:messages][0][:content]).to include('Client merge request description')
    end
  end
end
