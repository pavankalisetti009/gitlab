# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Utils::AiFeaturesCatalogue, feature_category: :ai_abstraction_layer do
  describe 'definitions' do
    it 'has a valid :feature_category set', :aggregate_failures do
      feature_categories = Gitlab::FeatureCategories.default.categories.map(&:to_sym).to_set

      described_class::LIST.each do |action, completion|
        expect(completion[:feature_category]).to be_a(Symbol)
        expect(feature_categories)
          .to(include(completion[:feature_category]), "expected #{action} to declare a valid feature_category")
      end
    end

    it 'has all fields set', :aggregate_failures do
      described_class::LIST.each_value do |completion|
        expect(completion).to include(:service_class,
          :prompt_class,
          :maturity,
          :self_managed,
          :internal,
          :execute_method)
      end
    end
  end

  describe '#external' do
    it 'returns external actions' do
      expect(described_class.external.values.pluck(:internal))
        .not_to include(true)
    end
  end

  describe '#with_service_class' do
    it 'returns external actions' do
      expect(described_class.with_service_class.values.pluck(:service_class))
        .not_to include(nil)
    end
  end

  describe '#for_saas_only' do
    it 'returns Saas-only actions' do
      expect(described_class.for_saas_only.values.pluck(:self_managed))
        .not_to include(true)
    end
  end

  describe '#for_saas_and_sm' do
    it 'returns actions available for both SaaS and Self-Managed' do
      expect(described_class.for_saas_and_sm.values.pluck(:self_managed))
        .not_to include(false)
    end
  end

  describe '#ga' do
    it 'returns ga actions' do
      expect(described_class.ga.values.pluck(:ga))
        .not_to include(:experimental, :beta)
    end
  end

  describe '#search_by_name' do
    it 'returns defined value if name matches' do
      expect(described_class.search_by_name(:resolve_vulnerability))
        .to eq(described_class::LIST[:resolve_vulnerability])
    end

    it 'returns value found by alternate name if name does not match' do
      expect(described_class.search_by_name(:duo_chat))
        .to eq(described_class::LIST[:chat])
    end

    it 'returns nil if nothing matches' do
      expect(described_class.search_by_name(:test))
        .to be_nil
    end

    it 'returns nil when name is nil' do
      expect(described_class.search_by_name(nil)).to be_nil
    end
  end

  describe 'LIST' do
    subject(:list) { described_class::LIST }

    it 'has correct definition for :ai_catalog' do
      expect(list[:ai_catalog]).to eq({
        service_class: nil,
        prompt_class: nil,
        feature_category: :workflow_catalog,
        execute_method: nil,
        maturity: :experimental,
        self_managed: true,
        internal: true
      })
    end

    it 'has correct definition for :ai_catalog_flows' do
      expect(list[:ai_catalog_flows]).to eq({
        service_class: nil,
        prompt_class: nil,
        feature_category: :workflow_catalog,
        execute_method: nil,
        maturity: :beta,
        self_managed: true,
        internal: true
      })
    end

    it 'has correct definition for :ai_catalog_third_party_flows' do
      expect(list[:ai_catalog_third_party_flows]).to eq({
        service_class: nil,
        prompt_class: nil,
        feature_category: :workflow_catalog,
        execute_method: nil,
        maturity: :ga,
        self_managed: true,
        internal: true
      })
    end
  end

  describe '.effective_maturity' do
    let(:user) { nil }

    subject(:effective_maturity) { described_class.effective_maturity(feature_name) }

    context 'when feature does not exist' do
      let(:feature_name) { :non_existent_feature }

      it { is_expected.to be_nil }
    end

    context 'for features that do not use duo_agent_platform' do
      using RSpec::Parameterized::TableSyntax

      where(:feature_name, :base_maturity) do
        :chat                        | :ga
        :explain_vulnerability       | :ga
        :resolve_vulnerability       | :ga
        :generate_commit_message     | :ga
        :summarize_review            | :experimental
        :generate_description        | :experimental
        :summarize_new_merge_request | :beta
      end

      with_them do
        context 'on SaaS' do
          before do
            stub_saas_features(gitlab_com_subscriptions: true)
          end

          context 'when feature flag is enabled' do
            before do
              stub_feature_flags(ai_duo_agent_platform_ga_rollout: true)
            end

            it 'returns the base maturity' do
              expect(effective_maturity).to eq(base_maturity)
            end
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(ai_duo_agent_platform_ga_rollout: false)
            end

            it 'returns the base maturity' do
              expect(effective_maturity).to eq(base_maturity)
            end
          end
        end

        context 'on Self-Managed' do
          before do
            stub_saas_features(gitlab_com_subscriptions: false)
          end

          context 'when feature flag is enabled' do
            before do
              stub_feature_flags(ai_duo_agent_platform_ga_rollout: true)
            end

            it 'returns the base maturity' do
              expect(effective_maturity).to eq(base_maturity)
            end
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(ai_duo_agent_platform_ga_rollout: false)
            end

            it 'returns the base maturity' do
              expect(effective_maturity).to eq(base_maturity)
            end
          end
        end
      end
    end

    context 'for features that use duo_agent_platform' do
      using RSpec::Parameterized::TableSyntax

      where(:feature_name, :base_maturity) do
        :agentic_chat        | :experimental
        :duo_workflow        | :beta
        :duo_agent_platform  | :beta
        :ai_catalog          | :experimental
      end

      with_them do
        context 'on SaaS' do
          before do
            stub_saas_features(gitlab_com_subscriptions: true)
          end

          context 'when feature flag is enabled' do
            before do
              stub_feature_flags(ai_duo_agent_platform_ga_rollout: true)
            end

            it 'returns GA maturity' do
              expect(effective_maturity).to eq(:ga)
            end

            context 'with a user' do
              let(:user) { create(:user) }

              it 'returns GA maturity when feature flag is enabled for user' do
                expect(effective_maturity).to eq(:ga)
              end
            end
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(ai_duo_agent_platform_ga_rollout: false)
            end

            it 'returns the base maturity' do
              expect(effective_maturity).to eq(base_maturity)
            end

            context 'with a user' do
              let(:user) { create(:user) }

              it 'returns the base maturity when feature flag is disabled for user' do
                expect(effective_maturity).to eq(base_maturity)
              end
            end
          end
        end

        context 'on Self-Managed' do
          before do
            stub_saas_features(gitlab_com_subscriptions: false)
          end

          context 'when ai_duo_agent_platform_ga_rollout_self_managed flag is enabled' do
            before do
              stub_feature_flags(ai_duo_agent_platform_ga_rollout_self_managed: true)
            end

            it 'returns GA maturity' do
              expect(effective_maturity).to eq(:ga)
            end
          end

          context 'when ai_duo_agent_platform_ga_rollout_self_managed flag is disabled' do
            before do
              stub_feature_flags(ai_duo_agent_platform_ga_rollout_self_managed: false)
            end

            it 'returns the base maturity' do
              expect(effective_maturity).to eq(base_maturity)
            end
          end
        end
      end
    end
  end

  describe '.instance_should_observe_ga_dap?' do
    let(:all_features) { described_class::LIST.keys }

    shared_examples 'is true for all DAP features only', :aggregate_failures do
      specify do
        all_features.each do |feature|
          result = described_class.instance_should_observe_ga_dap?(feature)
          is_dap_feature = described_class.uses_duo_agent_platform?(feature)

          expect(result).to eq(is_dap_feature)
        end
      end
    end

    context 'when SaaS', :saas do
      context 'when ai_duo_agent_platform_ga_rollout flag is enabled' do
        before do
          stub_feature_flags(ai_duo_agent_platform_ga_rollout: true)
        end

        it_behaves_like 'is true for all DAP features only'
      end

      context 'when ai_duo_agent_platform_ga_rollout flag is disabled' do
        before do
          stub_feature_flags(ai_duo_agent_platform_ga_rollout: false)
        end

        it 'is false for all features', :aggregate_failures do
          all_features.each do |feature|
            result = described_class.instance_should_observe_ga_dap?(feature)

            expect(result).to be(false)
          end
        end
      end
    end

    context 'when Self-Managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when ai_duo_agent_platform_ga_rollout_self_managed flag is enabled' do
        before do
          stub_feature_flags(ai_duo_agent_platform_ga_rollout_self_managed: true)
        end

        it_behaves_like 'is true for all DAP features only'
      end

      context 'when ai_duo_agent_platform_ga_rollout_self_managed flag is disabled' do
        before do
          stub_feature_flags(ai_duo_agent_platform_ga_rollout_self_managed: false)
        end

        it 'is false for all features', :aggregate_failures do
          all_features.each do |feature|
            result = described_class.instance_should_observe_ga_dap?(feature)

            expect(result).to be(false)
          end
        end
      end
    end
  end
end
