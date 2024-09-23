# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SelfSigned::AccessDataReader, feature_category: :cloud_connector do
  describe '#read_available_services' do
    let_it_be(:cs_cut_off_date) { Time.zone.parse("2024-02-15 00:00:00 UTC").utc }
    let_it_be(:cs_unit_primitives) { [:code_suggestions] }
    let_it_be(:cs_bundled_with) { { "duo_enterprise" => cs_unit_primitives, "duo_pro" => cs_unit_primitives } }

    let_it_be(:duo_chat_unit_primitives) { [:duo_chat, :documentation_search] }
    let_it_be(:duo_chat_bundled_with) do
      { "duo_enterprise" => duo_chat_unit_primitives, "duo_pro" => duo_chat_unit_primitives }
    end

    let_it_be(:backend) { 'gitlab-ai-gateway' }
    let_it_be(:gob_backend) { 'gitlab-observability-backend' }
    let_it_be(:sast_backend) { 'gitlab-security-gateway' }

    let_it_be(:self_hosted_models_cut_off_date) { Time.zone.parse("2024-10-17 00:00:00 UTC").utc }
    let_it_be(:duo_chat_cutoff_date) { Time.zone.parse("2024-10-17 00:00:00 UTC").utc }
    let_it_be(:self_hosted_models_bundled_with) { { "duo_enterprise" => [:code_suggestions, :duo_chat] } }

    let_it_be(:anthropic_proxy_bundled_with) do
      {
        "duo_enterprise" => %i[
          categorize_duo_chat_question
          documentation_search
          explain_vulnerability
          resolve_vulnerability
          generate_issue_description
          glab_ask_git_command
          summarize_issue_discussions
          generate_commit_message
          review_merge_request
          summarize_review
        ]
      }
    end

    let_it_be(:vertex_ai_proxy_bundled_with) do
      {
        "duo_enterprise" => %i[
          documentation_search
          duo_chat
          explain_code
          explain_vulnerability
          generate_commit_message
          generate_cube_query
          glab_ask_git_command
          resolve_vulnerability
          semantic_search_issue
          summarize_issue_discussions
          summarize_merge_request
        ]
      }
    end

    let_it_be(:generate_description_bundled_with) do
      {
        "duo_enterprise" => %i[
          generate_issue_description
        ]
      }
    end

    let_it_be(:explain_vulnerability_bundled_with) do
      {
        "duo_enterprise" => %i[
          explain_vulnerability
        ]
      }
    end

    let_it_be(:troubleshoot_job_bundled_with) do
      {
        "duo_enterprise" => %i[
          troubleshoot_job
        ]
      }
    end

    let_it_be(:resolve_vulnerability_bundled_with) do
      {
        "duo_enterprise" => %i[
          resolve_vulnerability
        ]
      }
    end

    let_it_be(:generate_commit_message_bundled_with) do
      {
        "duo_enterprise" => %i[
          generate_commit_message
        ]
      }
    end

    let_it_be(:glab_ask_git_command_bundled_with) do
      {
        "duo_enterprise" => %i[
          glab_ask_git_command
        ]
      }
    end

    let_it_be(:summarize_comments_bundled_with) do
      {
        "duo_enterprise" => %i[
          summarize_comments
        ]
      }
    end

    let_it_be(:observability_all_bundled_with) do
      {
        "observability" => %i[
          observability_all
        ]
      }
    end

    let_it_be(:sast_bundled_with) do
      {
        "_irrelevant_" => %i[
          security_scans
        ]
      }
    end

    include_examples 'access data reader' do
      let_it_be(:available_service_data_class) { CloudConnector::SelfSigned::AvailableServiceData }
      let_it_be(:arguments_map) do
        {
          code_suggestions: [cs_cut_off_date, cs_bundled_with, backend],
          duo_chat: [duo_chat_cutoff_date, duo_chat_bundled_with, backend],
          anthropic_proxy: [nil, anthropic_proxy_bundled_with, backend],
          vertex_ai_proxy: [nil, vertex_ai_proxy_bundled_with, backend],
          resolve_vulnerability: [nil, resolve_vulnerability_bundled_with, backend],
          self_hosted_models: [self_hosted_models_cut_off_date, self_hosted_models_bundled_with, backend],
          generate_description: [nil, generate_description_bundled_with, backend],
          generate_commit_message: [nil, generate_commit_message_bundled_with, backend],
          glab_ask_git_command: [nil, glab_ask_git_command_bundled_with, backend],
          explain_vulnerability: [nil, explain_vulnerability_bundled_with,
            backend],
          summarize_comments: [nil, summarize_comments_bundled_with, backend],
          observability_all: [nil, observability_all_bundled_with, gob_backend],
          troubleshoot_job: [nil, troubleshoot_job_bundled_with, backend],
          sast: [nil, sast_bundled_with, sast_backend]
        }
      end
    end
  end
end
