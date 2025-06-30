# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Embeddings::Code::VertexText, feature_category: :code_suggestions do
  describe '.generate_embeddings' do
    subject(:generate_embeddings) do
      described_class.generate_embeddings(
        contents,
        unit_primitive: unit_primitive,
        model: model,
        user: user
      )
    end

    let(:contents) { %w[content-1 content-2 content-3 content-4 content-5] }
    let(:unit_primitive) { 'embeddings_generation' }
    let(:model) { 'test-embedding-model' }
    let(:user) { instance_double(User) }

    let(:embeddings) do
      [
        [1, 1],
        [2, 2],
        [3, 3],
        [4, 4],
        [5, 5]
      ]
    end

    let(:embeddings_model) do
      instance_double(
        Gitlab::Llm::VertexAi::Embeddings::Text,
        execute: embeddings
      )
    end

    before do
      allow(Gitlab::Llm::VertexAi::Embeddings::Text).to receive(:new).and_return(embeddings_model)
    end

    it 'initializes the correct model class with the expected parameters' do
      expect(Gitlab::Llm::VertexAi::Embeddings::Text).to receive(:new).with(
        contents,
        user: user,
        tracking_context: { action: 'embedding' },
        unit_primitive: unit_primitive,
        model: model
      )

      expect(embeddings_model).to receive(:execute).and_return(embeddings)

      generate_embeddings
    end
  end
end
