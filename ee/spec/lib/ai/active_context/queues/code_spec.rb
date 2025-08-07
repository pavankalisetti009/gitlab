# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Queues::Code, feature_category: :code_suggestions do
  describe '.number_of_shards' do
    it 'returns 1' do
      expect(described_class.number_of_shards).to eq(1)
    end
  end

  describe '.queues' do
    it 'includes the code queue' do
      expect(ActiveContext::Queues.queues).to include('ai_activecontext_queues:{code}')
    end
  end
end
