# frozen_string_literal: true

require "spec_helper"

RSpec.describe Resolvers::Ai::Chat::AvailableModelsResolver, :saas, feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:args) { { root_namespace_id: GitlabSchema.id_from_object(group) } }

  describe "#resolve" do
    subject(:resolver) do
      resolve(described_class, obj: nil, args: args, ctx: { current_user: current_user })
    end

    before do
      allow(Ability).to receive(:allowed?)
        .with(current_user, :access_duo_agentic_chat, group)
        .and_return(true)
    end

    context "when service returns successful result" do
      let(:service_result) do
        ServiceResponse.success(payload: {
          "models" => [
            { "name" => "Claude Sonnet 4.0 - Anthropic", "identifier" => "claude_sonnet_4_20250514" },
            { "name" => "Claude Sonnet 4.0 - Vertex", "identifier" => "claude_sonnet_4_20250514_vertex" },
            { "name" => "Claude Sonnet 3.7 - Anthropic", "identifier" => "claude_sonnet_3_7_20250219" },
            { "name" => "Claude Sonnet 3.7 - Vertex", "identifier" => "claude_sonnet_3_7_20250219_vertex" }
          ],
          "unit_primitives" => [
            {
              "feature_setting" => "duo_agent_platform",
              "default_model" => "claude_sonnet_4_20250514",
              "selectable_models" => %w[claude_sonnet_4_20250514 claude_sonnet_3_7_20250219],
              "beta_models" => []
            }
          ]
        })
      end

      before do
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(service_result)
        end
      end

      it "returns the correct structure with default and selectable models" do
        expect(resolver).to eq({
          default_model: { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
          selectable_models: [
            { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
            { name: "Claude Sonnet 3.7 - Anthropic", ref: "claude_sonnet_3_7_20250219" }
          ],
          pinned_model: nil
        })
      end

      context "when there is a pinned model" do
        let!(:pinned_feature_setting) do
          create(:ai_namespace_feature_setting,
            namespace: group,
            feature: :duo_agent_platform,
            offered_model_ref: "claude_sonnet_3_7_20250219")
        end

        it "returns the pinned model information" do
          expect(resolver).to eq({
            default_model: { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
            selectable_models: [
              { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
              { name: "Claude Sonnet 3.7 - Anthropic", ref: "claude_sonnet_3_7_20250219" }
            ],
            pinned_model: { name: "Claude Sonnet 3.7 - Anthropic", ref: "claude_sonnet_3_7_20250219" }
          })
        end
      end

      context "when no feature setting exists" do
        it "returns nil for pinned model when no feature setting exists" do
          expect(resolver).to eq({
            default_model: { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
            selectable_models: [
              { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
              { name: "Claude Sonnet 3.7 - Anthropic", ref: "claude_sonnet_3_7_20250219" }
            ],
            pinned_model: nil
          })
        end
      end

      context "when feature setting is not pinned" do
        let!(:unpinned_feature_setting) do
          create(:ai_namespace_feature_setting,
            namespace: group,
            feature: :duo_agent_platform,
            offered_model_ref: nil)
        end

        it "returns nil for pinned model when not pinned" do
          expect(resolver).to eq({
            default_model: { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
            selectable_models: [
              { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
              { name: "Claude Sonnet 3.7 - Anthropic", ref: "claude_sonnet_3_7_20250219" }
            ],
            pinned_model: nil
          })
        end
      end

      context "when feature setting service fails" do
        before do
          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: "Service failed"))
          end
        end

        it "returns nil for pinned model when service fails" do
          expect(resolver).to eq({
            default_model: { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
            selectable_models: [
              { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
              { name: "Claude Sonnet 3.7 - Anthropic", ref: "claude_sonnet_3_7_20250219" }
            ],
            pinned_model: nil
          })
        end
      end

      context "when feature setting returns ai_feature_setting payload" do
        let_it_be(:model) { create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219') }

        let_it_be(:feature_setting) do
          create(:ai_feature_setting, feature: :duo_agent_platform, self_hosted_model: model)
        end

        before do
          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: feature_setting))
          end
        end

        it "returns nil for pinned model when user_model_selection_available? is false" do
          expect(resolver).to eq({
            default_model: { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
            selectable_models: [
              { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
              { name: "Claude Sonnet 3.7 - Anthropic", ref: "claude_sonnet_3_7_20250219" }
            ],
            pinned_model: nil
          })
        end
      end

      context "when feature setting returns ai_namespace_feature_setting payload" do
        let_it_be(:feature_setting) do
          create(:ai_namespace_feature_setting,
            namespace: group,
            feature: :duo_agent_platform,
            offered_model_ref: "claude_sonnet_3_7_20250219")
        end

        before do
          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: feature_setting))
          end
        end

        it "returns the pinned model when user_model_selection_available? is true" do
          expect(resolver).to eq({
            default_model: { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
            selectable_models: [
              { name: "Claude Sonnet 4.0 - Anthropic", ref: "claude_sonnet_4_20250514" },
              { name: "Claude Sonnet 3.7 - Anthropic", ref: "claude_sonnet_3_7_20250219" }
            ],
            pinned_model: { name: "Claude Sonnet 3.7 - Anthropic", ref: "claude_sonnet_3_7_20250219" }
          })
        end
      end

      context "when duo_agent_platform feature setting is not found" do
        let(:service_result) do
          ServiceResponse.success(payload: {
            "models" => [
              { "name" => "Claude Sonnet", "identifier" => "claude-sonnet" }
            ],
            "unit_primitives" => [
              {
                "feature_setting" => "code_suggestions",
                "default_model" => "claude-sonnet",
                "selectable_models" => ["claude-sonnet"],
                "beta_models" => []
              }
            ]
          })
        end

        it "returns an empty list" do
          expect(resolver).to eq({ default_model: nil, selectable_models: [], pinned_model: nil })
        end
      end
    end

    context "when service returns failure result" do
      let(:service_result) do
        ServiceResponse.error(message: "API unavailable")
      end

      before do
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(service_result)
        end
      end

      it "returns empty result when service fails" do
        expect(resolver).to eq({
          default_model: nil,
          selectable_models: [],
          pinned_model: nil
        })
      end
    end

    context "when service returns nil" do
      before do
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(nil)
        end
      end

      it "returns empty result when service returns nil" do
        expect(resolver).to eq({ default_model: nil, selectable_models: [], pinned_model: nil })
      end
    end
  end
end
