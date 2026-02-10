# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Embeddings::ModelSelector, feature_category: :code_suggestions do
  shared_context 'on saas instance' do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
      allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
    end
  end

  shared_context 'on dedicated instance' do
    before do
      stub_saas_features(gitlab_com_subscriptions: false)
      allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
      allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
    end
  end

  shared_context 'on SM instance without self-hosted AIGW' do
    before do
      stub_saas_features(gitlab_com_subscriptions: false)
      allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
      allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
    end
  end

  shared_context 'on SM instance with self-hosted AIGW' do
    before do
      stub_saas_features(gitlab_com_subscriptions: false)
      allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
      allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(true)
    end
  end

  describe '.use_gitlab_selected_model?' do
    subject(:use_gitlab_selected_model) { described_class.use_gitlab_selected_model? }

    context 'on saas instance' do
      include_context 'on saas instance'

      it { is_expected.to be(true) }
    end

    context 'on dedicated instance' do
      include_context 'on dedicated instance'

      it { is_expected.to be(true) }
    end

    context 'on SM instance without self-hosted AIGW' do
      include_context 'on SM instance without self-hosted AIGW'

      it { is_expected.to be(true) }
    end

    context 'on SM instance with self-hosted AIGW' do
      include_context 'on SM instance with self-hosted AIGW'

      it { is_expected.to be(false) }
    end
  end

  describe '.for' do
    subject(:embedding_model) { described_class.for(model_metadata) }

    let(:model_metadata) { nil }

    shared_examples 'gitlab selects the model' do
      context 'when model_metadata is nil' do
        let(:model_metadata) { nil }

        it 'returns nil' do
          expect(embedding_model).to be_nil
        end
      end

      context 'when model_metadata[:model_ref] is not set' do
        let(:model_metadata) { { field: 'test_embeddings_field' } }

        it 'raises an error' do
          expect { embedding_model }.to raise_error(
            described_class::UnexpectedModelConfiguration,
            "`model_metadata` must have a `model_ref` and `field`"
          )
        end
      end

      context 'when model_metadata[:field] is not set' do
        let(:model_metadata) { { model_ref: 'model_001_reference' } }

        it 'raises an error' do
          expect { embedding_model }.to raise_error(
            described_class::UnexpectedModelConfiguration,
            "`model_metadata` must have a `model_ref` and `field`"
          )
        end
      end

      context 'when model_metadata has the required values' do
        before do
          stub_const("#{described_class}::MODELS_LOOKUP", models_lookup)
        end

        let(:models_lookup) { {} }
        let(:model_metadata) { { model_ref: 'model_001_reference', field: 'test_embeddings_field' } }

        it 'raises an error if model_ref is not in the MODELS_LOOKUP' do
          expect { embedding_model }.to raise_error(
            described_class::MissingModelDefinition,
            "Missing definitions for Gitlab-managed model: model_001_reference"
          )
        end

        context 'when model_ref is in the MODELS_LOOKUP' do
          let(:models_lookup) do
            {
              'model_001_reference' => {
                model: 'embedding-model-001',
                llm_class: Ai::ActiveContext::Embeddings::Code::VertexText,
                batch_size: 3
              }
            }
          end

          it 'returns the expected gitlab-selected model' do
            expect(embedding_model).to be_a(::ActiveContext::EmbeddingModel)
            expect(embedding_model.model_name).to eq('embedding-model-001')
            expect(embedding_model.field).to eq('test_embeddings_field')
            expect(embedding_model.llm_class).to eq(Ai::ActiveContext::Embeddings::Code::VertexText)
            expect(embedding_model.llm_params).to eq({ model: 'embedding-model-001', batch_size: 3 })
          end
        end
      end
    end

    context 'on saas instance' do
      include_context 'on saas instance'

      it_behaves_like 'gitlab selects the model'
    end

    context 'on dedicated instance' do
      include_context 'on dedicated instance'

      it_behaves_like 'gitlab selects the model'
    end

    context 'on SM instance without self-hosted AIGW' do
      include_context 'on SM instance without self-hosted AIGW'

      it_behaves_like 'gitlab selects the model'
    end

    context 'on SM instance with self-hosted AIGW' do
      include_context 'on SM instance with self-hosted AIGW'

      it { is_expected.to be_nil }
    end
  end
end
