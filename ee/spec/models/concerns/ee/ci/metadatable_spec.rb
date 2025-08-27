# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Ci::Metadatable, feature_category: :continuous_integration do
  let_it_be_with_refind(:processable) { create(:ci_processable, options: { script: 'echo' }) }

  before do
    # Remove when FF `read_from_new_ci_destinations` is removed
    processable.clear_memoization(:read_from_new_destination?)
    # Remove when FF `stop_writing_builds_metadata` is removed
    processable.clear_memoization(:can_write_metadata?)
  end

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
        processable.ensure_metadata.write_attribute(:secrets, metadata_secrets)
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

        context 'when FF `read_from_new_ci_destinations` is disabled' do
          before do
            stub_feature_flags(read_from_new_ci_destinations: false)
          end

          it 'returns metadata secrets' do
            expect(secrets).to eq(metadata_secrets)
            expect(processable.secrets?).to be(true)
          end
        end
      end
    end
  end

  describe '#secrets=' do
    let(:secrets) do
      {
        PASSWORD: { vault: { engine: { name: 'test', path: 'ops' }, path: 'test/db', field: 'test' } }
      }.deep_stringify_keys
    end

    subject(:set_secrets) { processable.secrets = secrets }

    it 'does not change metadata.secrets' do
      expect { set_secrets }
        .to not_change { processable.metadata.secrets }
    end

    context 'when FF `stop_writing_builds_metadata` is disabled' do
      before do
        stub_feature_flags(stop_writing_builds_metadata: false)
      end

      it 'sets the value into metadata.secrets' do
        set_secrets

        expect(processable.metadata.secrets).to eq(secrets)
      end
    end
  end
end
