# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Ci::Metadatable, feature_category: :continuous_integration do
  let_it_be_with_refind(:processable) { create(:ci_processable, options: { script: 'echo' }) }

  describe '#secrets' do
    let(:metadata_secrets) do
      {
        PASSWORD: { vault: { engine: { name: 'kv-v2', path: 'ops' }, path: 'test/db', field: 'metadata' } }
      }.deep_stringify_keys
    end

    let(:job_definition_secrets) do
      {
        PASSWORD: { vault: { engine: { name: 'kv-v2', path: 'ops' }, path: 'test/db', field: 'job_definition' } }
      }.deep_stringify_keys
    end

    subject(:secrets) { processable.secrets }

    it 'defaults to an empty hash' do
      expect(secrets).to eq({})
      expect(processable.secrets?).to be(false)
    end

    context 'when metadata secrets are present' do
      before do
        create(:ci_build_metadata, build: processable, secrets: metadata_secrets)
      end

      it 'returns metadata secrets' do
        expect(secrets).to eq(metadata_secrets)
        expect(processable.secrets?).to be(true)
      end

      context 'when job definition secrets are present' do
        before do
          updated_config = processable.job_definition.config.merge(secrets: job_definition_secrets)
          processable.job_definition.write_attribute(:config, updated_config)
        end

        it 'returns job definition secrets' do
          expect(secrets).to eq(job_definition_secrets)
          expect(processable.secrets?).to be(true)
        end
      end
    end
  end
end
