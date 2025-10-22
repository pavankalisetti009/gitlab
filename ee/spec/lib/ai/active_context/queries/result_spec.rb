# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Queries::Result, feature_category: :code_suggestions do
  context 'with a successful result' do
    subject(:result) do
      described_class.new(
        success: true,
        hits: hits
      )
    end

    let(:hits) do
      [
        { path: 'some/path', content: 'some content' },
        { path: 'dummy/path', content: 'dummy content' }
      ]
    end

    it { expect(result.success?).to be(true) }
    it { expect(result.to_a).to eq(hits) }
    it { expect(result.hits).to eq(hits) }
  end

  context 'with a failure result' do
    subject(:result) do
      described_class.new(
        success: false,
        error_code: described_class::ERROR_NO_EMBEDDINGS
      )
    end

    it { expect(result.success?).to be(false) }
    it { expect(result.error_code).to eq(described_class::ERROR_NO_EMBEDDINGS) }
  end
end
