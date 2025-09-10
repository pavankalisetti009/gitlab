# frozen_string_literal: true

require "spec_helper"

RSpec.describe Resolvers::Ai::Chat::AvailableModelsResolver, feature_category: :duo_chat do
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
              "feature_setting" => "duo_chat",
              "default_model" => "claude_sonnet_4_20250514_vertex",
              "selectable_models" => %w[claude_sonnet_4_20250514 claude_sonnet_4_20250514_vertex],
              "beta_models" => []
            },
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
          ]
        })
      end

      context "when duo_chat feature setting is not found" do
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
          expect(resolver).to eq({ default_model: nil, selectable_models: [] })
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
          selectable_models: []
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
        expect(resolver).to eq({ default_model: nil, selectable_models: [] })
      end
    end
  end
end
