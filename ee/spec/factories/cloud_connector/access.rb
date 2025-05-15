# frozen_string_literal: true

FactoryBot.define do
  factory :cloud_connector_access, class: 'CloudConnector::Access' do
    data do
      {
        available_services: [
          {
            name: "code_suggestions",
            serviceStartTime: "2024-02-15T00:00:00Z",
            bundledWith: %w[duo_pro]
          },
          {
            name: "duo_chat",
            serviceStartTime: nil,
            bundledWith: %w[duo_pro]
          }
        ]
      }
    end

    catalog do
      {
        backend_services: [
          {
            name: "ai_gateway",
            project_url: "https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist",
            group: "group::ai framework",
            jwt_aud: "gitlab-ai-gateway"
          },
          {
            name: "ai_gateway_agent",
            project_url: "unknown",
            group: "group::ai framework",
            jwt_aud: "gitlab-ai-gateway-agent"
          },
          {
            name: "duo_workflow_service",
            project_url: "https://gitlab.com/gitlab-org/duo-workflow/duo-workflow-service",
            group: "group:ai model validation",
            jwt_aud: "gitlab-duo-workflow-service"
          }
        ],
        unit_primitives: [
          {
            name: "agent_quick_actions",
            description: "Quick actions for agent.",
            group: "group::duo_chat",
            feature_category: "duo_chat",
            backend_services: ["ai_gateway_agent"],
            license_types: ["ultimate"]
          }
        ],
        add_ons: [
          { name: "duo_enterprise" },
          { name: "duo_pro" }
        ],
        license_types: [
          { name: "premium" },
          { name: "ultimate" }
        ]
      }
    end

    trait :current do
      updated_at { Time.current }
    end

    trait :stale do
      updated_at { Time.current - ::CloudConnector::Access::STALE_PERIOD - 1.minute }
    end
  end
end
