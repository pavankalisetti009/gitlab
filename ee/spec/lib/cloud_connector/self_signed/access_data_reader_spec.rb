# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- Test uses a lot of helpers, and will be reviewed in https://gitlab.com/gitlab-org/gitlab/-/issues/495021
RSpec.describe CloudConnector::SelfSigned::AccessDataReader, feature_category: :cloud_connector do
  describe '#read_available_services' do
    let(:cs_cut_off_date) { Time.zone.parse("2024-02-15 00:00:00 UTC").utc }
    let(:cs_unit_primitives) { [:code_suggestions] }
    let(:cs_bundled_with) { { "duo_enterprise" => cs_unit_primitives, "duo_pro" => cs_unit_primitives } }

    let(:duo_chat_unit_primitives) { [:duo_chat, :documentation_search] }
    let(:duo_chat_ent_unit_primitives) do
      duo_chat_unit_primitives + [:ask_build, :ask_commit, :ask_epic, :ask_issue, :ask_merge_request]
    end

    let(:duo_chat_bundled_with) do
      { "duo_enterprise" => duo_chat_ent_unit_primitives, "duo_pro" => duo_chat_unit_primitives }
    end

    let(:backend) { 'gitlab-ai-gateway' }
    let(:gob_backend) { 'gitlab-observability-backend' }
    let(:sast_backend) { 'gitlab-security-gateway' }
    let(:duo_workflow_backend) { 'gitlab-duo-workflow-service' }

    let(:self_hosted_models_cut_off_date) { Time.zone.parse("2024-10-17 00:00:00 UTC").utc }
    let(:ai_proxy_cut_off_date) { Time.zone.parse("2024-10-17 00:00:00 UTC").utc }
    let(:duo_chat_cut_off_date) { Time.zone.parse("2024-10-17 00:00:00 UTC").utc }
    let(:glab_ask_git_command_cut_off_date) { Time.zone.parse("2024-10-17 00:00:00 UTC").utc }
    let(:generate_commit_message_cut_off_date) { Time.zone.parse("2024-10-17 00:00:00 UTC").utc }

    let(:anthropic_proxy_bundled_with) do
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

    let(:vertex_ai_proxy_bundled_with) do
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

    let(:generate_description_bundled_with) do
      {
        "duo_enterprise" => %i[
          generate_issue_description
        ]
      }
    end

    let(:explain_vulnerability_bundled_with) do
      {
        "duo_enterprise" => %i[
          explain_vulnerability
        ]
      }
    end

    let(:troubleshoot_job_bundled_with) do
      {
        "duo_enterprise" => %i[
          troubleshoot_job
        ]
      }
    end

    let(:resolve_vulnerability_bundled_with) do
      {
        "duo_enterprise" => %i[
          resolve_vulnerability
        ]
      }
    end

    let(:generate_commit_message_bundled_with) do
      {
        "duo_enterprise" => %i[
          generate_commit_message
        ]
      }
    end

    let(:glab_ask_git_command_bundled_with) do
      {
        "duo_enterprise" => %i[
          glab_ask_git_command
        ]
      }
    end

    let(:summarize_comments_bundled_with) do
      {
        "duo_enterprise" => %i[
          summarize_comments
        ]
      }
    end

    let(:observability_all_bundled_with) do
      {
        "observability" => %i[
          observability_all
        ]
      }
    end

    let(:sast_bundled_with) do
      {
        "_irrelevant_" => %i[
          security_scans
        ]
      }
    end

    let(:duo_workflow_bundled_with) do
      {
        "_irrelevant" => %i[
          duo_workflow_execute_workflow
          duo_workflow_generate_token
        ]
      }
    end

    let(:self_hosted_models_bundled_with) do
      { "duo_enterprise" => [:code_suggestions, :duo_chat] }
    end

    include_examples 'access data reader' do
      let(:available_service_data_class) { CloudConnector::SelfSigned::AvailableServiceData }
      let(:arguments_map) do
        {
          code_suggestions: [cs_cut_off_date, cs_bundled_with, backend],
          duo_chat: [duo_chat_cut_off_date, duo_chat_bundled_with, backend],
          anthropic_proxy: [ai_proxy_cut_off_date, anthropic_proxy_bundled_with, backend],
          vertex_ai_proxy: [ai_proxy_cut_off_date, vertex_ai_proxy_bundled_with, backend],
          resolve_vulnerability: [nil, resolve_vulnerability_bundled_with, backend],
          self_hosted_models: [self_hosted_models_cut_off_date, self_hosted_models_bundled_with, backend],
          generate_description: [nil, generate_description_bundled_with, backend],
          generate_commit_message: [generate_commit_message_cut_off_date, generate_commit_message_bundled_with,
            backend],
          glab_ask_git_command: [glab_ask_git_command_cut_off_date, glab_ask_git_command_bundled_with, backend],
          explain_vulnerability: [nil, explain_vulnerability_bundled_with, backend],
          summarize_comments: [nil, summarize_comments_bundled_with, backend],
          observability_all: [nil, observability_all_bundled_with, gob_backend],
          troubleshoot_job: [nil, troubleshoot_job_bundled_with, backend],
          sast: [nil, sast_bundled_with, sast_backend],
          duo_workflow: [nil, duo_workflow_bundled_with, duo_workflow_backend]
        }
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
