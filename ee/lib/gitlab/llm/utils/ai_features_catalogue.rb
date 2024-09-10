# frozen_string_literal: true

module Gitlab
  module Llm
    module Utils
      class AiFeaturesCatalogue
        LIST = {
          explain_vulnerability: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :vulnerability_management,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: false
          },
          resolve_vulnerability: {
            service_class: ::Gitlab::Llm::Completions::ResolveVulnerability,
            prompt_class: ::Gitlab::Llm::Templates::Vulnerabilities::ResolveVulnerability,
            feature_category: :vulnerability_management,
            execute_method: ::Llm::ResolveVulnerabilityService,
            maturity: :ga,
            self_managed: true,
            internal: false
          },
          summarize_comments: {
            service_class: ::Gitlab::Llm::Completions::SummarizeAllOpenNotes,
            prompt_class: nil,
            feature_category: :ai_abstraction_layer,
            execute_method: ::Llm::GenerateSummaryService,
            maturity: :beta,
            self_managed: false,
            internal: false
          },
          summarize_review: {
            service_class: ::Gitlab::Llm::Anthropic::Completions::SummarizeReview,
            prompt_class: ::Gitlab::Llm::Templates::SummarizeReview,
            feature_category: :ai_abstraction_layer,
            execute_method: ::Llm::MergeRequests::SummarizeReviewService,
            maturity: :experimental,
            self_managed: false,
            internal: false
          },
          explain_code: {
            service_class: ::Gitlab::Llm::VertexAi::Completions::ExplainCode,
            prompt_class: ::Gitlab::Llm::VertexAi::Templates::ExplainCode,
            feature_category: :ai_abstraction_layer,
            execute_method: ::Llm::ExplainCodeService,
            maturity: :experimental,
            self_managed: false,
            internal: false
          },
          generate_description: {
            service_class: ::Gitlab::Llm::Anthropic::Completions::GenerateDescription,
            aigw_service_class: ::Gitlab::Llm::AiGateway::Completions::GenerateDescription,
            prompt_class: ::Gitlab::Llm::Templates::GenerateDescription,
            feature_category: :ai_abstraction_layer,
            execute_method: ::Llm::GenerateDescriptionService,
            maturity: :experimental,
            self_managed: false,
            internal: false
          },
          generate_commit_message: {
            service_class: ::Gitlab::Llm::Completions::GenerateCommitMessage,
            prompt_class: ::Gitlab::Llm::Templates::GenerateCommitMessage,
            feature_category: :code_review_workflow,
            execute_method: ::Llm::GenerateCommitMessageService,
            maturity: :ga,
            self_managed: true,
            internal: false
          },
          chat: {
            service_class: ::Gitlab::Llm::Completions::Chat,
            prompt_class: nil,
            feature_category: :duo_chat,
            execute_method: ::Llm::ChatService,
            maturity: :ga,
            self_managed: true,
            internal: false
          },
          summarize_new_merge_request: {
            service_class: ::Gitlab::Llm::VertexAi::Completions::SummarizeNewMergeRequest,
            prompt_class: ::Gitlab::Llm::Templates::SummarizeNewMergeRequest,
            feature_category: :code_review_workflow,
            execute_method: ::Llm::SummarizeNewMergeRequestService,
            maturity: :experimental,
            self_managed: false,
            internal: false
          },
          generate_cube_query: {
            service_class: ::Gitlab::Llm::VertexAi::Completions::GenerateCubeQuery,
            prompt_class: ::Gitlab::Llm::VertexAi::Templates::GenerateCubeQuery,
            feature_category: :product_analytics_visualization,
            execute_method: ::Llm::ProductAnalytics::GenerateCubeQueryService,
            maturity: :experimental,
            self_managed: false,
            internal: false
          },
          categorize_question: {
            service_class: ::Gitlab::Llm::Anthropic::Completions::CategorizeQuestion,
            prompt_class: ::Gitlab::Llm::Templates::CategorizeQuestion,
            feature_category: :duo_chat,
            execute_method: ::Llm::Internal::CategorizeChatQuestionService,
            maturity: :ga,
            self_managed: false,
            internal: true
          },
          review_merge_request: {
            service_class: ::Gitlab::Llm::Anthropic::Completions::ReviewMergeRequest,
            prompt_class: ::Gitlab::Llm::Templates::ReviewMergeRequest,
            feature_category: :code_review_workflow,
            execute_method: ::Llm::ReviewMergeRequestService,
            maturity: :experimental,
            self_managed: false,
            internal: true
          },
          glab_ask_git_command: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :source_code_management,
            execute_method: ::Llm::GitCommandService,
            maturity: :ga,
            self_managed: true,
            internal: true
          }
        }.freeze

        def self.external
          LIST.select { |_, v| v[:internal] == false }
        end

        def self.with_service_class
          LIST.select { |_, v| v[:service_class].present? }
        end

        def self.for_saas
          LIST.select { |_, v| v[:self_managed] == false }
        end

        def self.for_sm
          LIST.select { |_, v| v[:self_managed] == true }
        end

        def self.ga
          LIST.select { |_, v| v[:maturity] == :ga }
        end
      end
    end
  end
end
