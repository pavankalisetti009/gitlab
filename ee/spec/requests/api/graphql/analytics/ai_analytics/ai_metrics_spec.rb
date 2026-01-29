# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'aiMetrics', :freeze_time, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, name: 'my-group') }
  let_it_be(:current_user) { create(:user, reporter_of: group) }
  let_it_be(:ghost_user) { create(:user, :ghost) }

  let(:ai_metrics_fields) do
    query_graphql_field(:aiMetrics, filter_params, fields)
  end

  let(:filter_params) { {} }
  let(:expected_filters) { {} }

  shared_examples 'common ai metrics' do
    let(:fields) do
      <<~FIELDS
        codeSuggestionsContributorsCount
        codeContributorsCount
        codeSuggestionsShownCount
        codeSuggestionsAcceptedCount
        duoChatContributorsCount
        duoAssignedUsersCount
        duoUsedCount
        rootCauseAnalysisUsersCount
        codeSuggestions(languages: ["ruby"], ideNames: ["ide1"]) {
          shownCount
          acceptedCount
          contributorsCount
          ideNames
          languages
          shownLinesOfCode
          acceptedLinesOfCode
        }
        codeReview {
          encounterDuoCodeReviewErrorDuringReviewEventCount
          findNoIssuesDuoCodeReviewAfterReviewEventCount
          findNothingToReviewDuoCodeReviewOnMrEventCount
          postCommentDuoCodeReviewOnDiffEventCount
          reactThumbsUpOnDuoCodeReviewCommentEventCount
          reactThumbsDownOnDuoCodeReviewCommentEventCount
          requestReviewDuoCodeReviewOnMrByAuthorEventCount
          requestReviewDuoCodeReviewOnMrByNonAuthorEventCount
          excludedFilesFromDuoCodeReviewEventCount
        }

        chat {
          requestDuoChatResponseEventCount
        }

        troubleshoot {
          troubleshootJobEventCount
        }

        mcp {
          startMcpToolCallEventCount
          finishMcpToolCallEventCount
        }

        agentPlatform(flowTypes: ["chat"], not: { flowTypes: ["pipeline"]}) {
          createdSessionEventCount
          startedSessionEventCount
          finishedSessionEventCount
          droppedSessionEventCount
          stoppedSessionEventCount
          resumedSessionEventCount

          flowMetrics {
            flowType
            sessionsCount
            medianExecutionTime
            usersCount
            completionRate
          }

          userFlowCounts {
            nodes {
              user {
                username
              }
              flowType
              sessionsCount
            }
          }
        }
      FIELDS
    end

    let(:from) { '2024-05-01'.to_date }
    let(:to) { '2024-05-31'.to_date }
    let(:filter_params) { { startDate: from, endDate: to } }
    let(:expected_filters) { { from: from, to: to, namespace: namespace, fields: an_instance_of(Array) } }
    let(:code_suggestions_expected_filters) { expected_filters.merge(languages: ['ruby'], ide_names: ['ide1']) }

    let(:ai_metrics_service_payload) do
      {
        code_contributors_count: 10,
        duo_chat_contributors_count: 8,
        duo_assigned_users_count: 18,
        duo_used_count: 17,
        # Experimental fields below were deprecated in 17.11.
        # They can be removed after one release without deprecation process.
        code_suggestions_contributors_count: 3,
        code_suggestions_shown_count: 5,
        code_suggestions_accepted_count: 2,
        root_cause_analysis_users_count: 20
      }
    end

    let(:code_suggestion_usage_service_payload) do
      {
        contributors_count: 3,
        shown_count: 20,
        accepted_count: 30,
        languages: %w[csharp go],
        ide_names: %w[ide1 ide2],
        accepted_lines_of_code: 100,
        shown_lines_of_code: 200
      }
    end

    let(:usage_event_count_service_payload) do
      {
        encounter_duo_code_review_error_during_review_event_count: 10,
        find_no_issues_duo_code_review_after_review_event_count: 20,
        find_nothing_to_review_duo_code_review_on_mr_event_count: 30,
        post_comment_duo_code_review_on_diff_event_count: 40,
        react_thumbs_up_on_duo_code_review_comment_event_count: 50,
        react_thumbs_down_on_duo_code_review_comment_event_count: 60,
        request_review_duo_code_review_on_mr_by_author_event_count: 70,
        request_review_duo_code_review_on_mr_by_non_author_event_count: 80,
        excluded_files_from_duo_code_review_event_count: 90,
        request_duo_chat_response_event_count: 1,
        troubleshoot_job_event_count: 2,
        start_mcp_tool_call_event_count: 3,
        finish_mcp_tool_call_event_count: 4
      }
    end

    let(:agent_platform_flow_metrics_service_payload) do
      [
        {
          'flow_type' => 'fix_pipeline',
          'sessions_count' => 1,
          'median_execution_time' => 10,
          'users_count' => 1,
          'completion_rate' => 100
        },
        {
          'flow_type' => 'code_review',
          'sessions_count' => 2,
          'median_execution_time' => 11,
          'users_count' => 2,
          'completion_rate' => 50
        }
      ]
    end

    let(:agent_platform_user_flow_count_service_payload) do
      [
        {
          'flow_type' => 'fix_pipeline',
          'sessions_count' => 10,
          'user_id' => current_user.id
        },
        {
          'flow_type' => 'chat',
          'sessions_count' => 20,
          'user_id' => -999
        }
      ]
    end

    let(:agent_platform_event_count_service_payload) do
      {
        created_session_event_count: 10,
        started_session_event_count: 20,
        finished_session_event_count: 30,
        dropped_session_event_count: 40,
        stopped_session_event_count: 50,
        resumed_session_event_count: 60
      }
    end

    before do
      allow_next_instance_of(::Analytics::AiAnalytics::AiMetricsService,
        current_user, hash_including(expected_filters)) do |instance|
        allow(instance).to receive(:execute)
          .and_return(ServiceResponse.success(payload: ai_metrics_service_payload))
      end

      allow_next_instance_of(::Analytics::AiAnalytics::CodeSuggestionUsageService,
        current_user, hash_including(code_suggestions_expected_filters)) do |instance|
        allow(instance).to receive(:execute)
          .and_return(ServiceResponse.success(payload: code_suggestion_usage_service_payload))
      end

      allow_next_instance_of(::Analytics::AiAnalytics::UsageEventCountService,
        current_user, hash_including(expected_filters)) do |instance|
        allow(instance).to receive(:execute)
          .and_return(ServiceResponse.success(payload: usage_event_count_service_payload))
      end

      allow_next_instance_of(::Analytics::AiAnalytics::AgentPlatform::FlowMetricsService,
        current_user, hash_including(expected_filters.except(:fields))) do |instance|
        allow(instance).to receive(:execute)
          .and_return(ServiceResponse.success(payload: agent_platform_flow_metrics_service_payload))
      end

      allow_next_instance_of(::Analytics::AiAnalytics::AgentPlatform::EventCountService,
        current_user, hash_including(expected_filters)) do |instance|
        allow(instance).to receive(:execute)
          .and_return(ServiceResponse.success(payload: agent_platform_event_count_service_payload))
      end

      allow_next_instance_of(::Analytics::AiAnalytics::AgentPlatform::UserFlowCountService,
        current_user, hash_including(expected_filters.except(:fields))) do |instance|
        allow(instance).to receive(:execute)
          .and_return(ServiceResponse.success(payload: agent_platform_user_flow_count_service_payload))
      end

      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
        .with(current_user, :read_pro_ai_analytics, anything)
        .and_return(true)

      post_graphql(query, current_user: current_user)
    end

    it 'returns all metrics' do
      expected_results = {
        'agentPlatform' => {
          'createdSessionEventCount' => 10,
          'startedSessionEventCount' => 20,
          'finishedSessionEventCount' => 30,
          'droppedSessionEventCount' => 40,
          'stoppedSessionEventCount' => 50,
          'resumedSessionEventCount' => 60,
          'flowMetrics' => [
            {
              'medianExecutionTime' => 10.0,
              'completionRate' => 100.0,
              'flowType' => 'fix_pipeline',
              'sessionsCount' => 1,
              'usersCount' => 1
            },
            {
              'medianExecutionTime' => 11.0,
              'completionRate' => 50.0,
              'flowType' => 'code_review',
              'sessionsCount' => 2,
              'usersCount' => 2
            }
          ],
          'userFlowCounts' => {
            'nodes' => [
              {
                'flowType' => 'fix_pipeline',
                'sessionsCount' => 10,
                'user' => { 'username' => current_user.username }
              },
              {
                'flowType' => 'chat',
                'sessionsCount' => 20,
                'user' => { 'username' => ghost_user.username }
              }
            ]
          }
        },
        'codeSuggestionsContributorsCount' => 3,
        'codeContributorsCount' => 10,
        'codeSuggestionsShownCount' => 5,
        'codeSuggestionsAcceptedCount' => 2,
        'duoChatContributorsCount' => 8,
        'duoAssignedUsersCount' => 18,
        'duoUsedCount' => 17,
        'rootCauseAnalysisUsersCount' => 20,
        'codeSuggestions' => {
          'contributorsCount' => 3,
          'shownCount' => 20,
          'acceptedCount' => 30,
          'ideNames' => %w[ide1 ide2],
          'languages' => %w[csharp go],
          'acceptedLinesOfCode' => 100,
          'shownLinesOfCode' => 200
        },
        'codeReview' => {
          'encounterDuoCodeReviewErrorDuringReviewEventCount' => 10,
          'findNoIssuesDuoCodeReviewAfterReviewEventCount' => 20,
          'findNothingToReviewDuoCodeReviewOnMrEventCount' => 30,
          'postCommentDuoCodeReviewOnDiffEventCount' => 40,
          'reactThumbsUpOnDuoCodeReviewCommentEventCount' => 50,
          'reactThumbsDownOnDuoCodeReviewCommentEventCount' => 60,
          'requestReviewDuoCodeReviewOnMrByAuthorEventCount' => 70,
          'requestReviewDuoCodeReviewOnMrByNonAuthorEventCount' => 80,
          'excludedFilesFromDuoCodeReviewEventCount' => 90
        },
        'chat' => {
          'requestDuoChatResponseEventCount' => 1
        },
        'troubleshoot' => {
          'troubleshootJobEventCount' => 2
        },
        'mcp' => {
          'startMcpToolCallEventCount' => 3,
          'finishMcpToolCallEventCount' => 4
        }
      }

      expect(ai_metrics).to eq(expected_results)
    end

    context 'when startDate is after endDate' do
      let(:filter_params) { { startDate: '2024-07-01'.to_date, endDate: '2024-06-30'.to_date } }

      it 'returns an error' do
        expect_graphql_errors_to_include("start date cannot be after end date")
        expect(ai_metrics).to be_nil
      end
    end

    context 'when AiMetrics service returns only part of queried fields' do
      let(:ai_metrics_service_payload) do
        {
          code_contributors_count: 10,
          code_suggestions_contributors_count: 3,
          code_suggestions_shown_count: 5,
          code_suggestions_accepted_count: 2
        }
      end

      let(:code_suggestion_usage_service_payload) do
        {}
      end

      let(:agent_platform_flow_metrics_service_payload) do
        {}
      end

      let(:agent_platform_user_flow_count_service_payload) do
        []
      end

      let(:agent_platform_event_count_service_payload) do
        {
          created_session_event_count: 999
        }
      end

      let(:usage_event_count_service_payload) do
        {
          post_comment_duo_code_review_on_diff_event_count: 99,
          finish_mcp_tool_call_event_count: 5
        }
      end

      it 'returns all metrics filled by default' do
        expected_results = {
          'agentPlatform' => {
            'createdSessionEventCount' => 999,
            'droppedSessionEventCount' => nil,
            'finishedSessionEventCount' => nil,
            'resumedSessionEventCount' => nil,
            'startedSessionEventCount' => nil,
            'stoppedSessionEventCount' => nil,
            'flowMetrics' => [],
            'userFlowCounts' => { 'nodes' => [] }
          },
          'codeSuggestionsContributorsCount' => 3,
          'codeContributorsCount' => 10,
          'codeSuggestionsShownCount' => 5,
          'codeSuggestionsAcceptedCount' => 2,
          'duoChatContributorsCount' => nil,
          'duoAssignedUsersCount' => nil,
          'duoUsedCount' => nil,
          'rootCauseAnalysisUsersCount' => nil,
          'codeSuggestions' => {
            'contributorsCount' => nil,
            'shownCount' => nil,
            'acceptedCount' => nil,
            'ideNames' => nil,
            'languages' => nil,
            'acceptedLinesOfCode' => nil,
            'shownLinesOfCode' => nil
          },
          'codeReview' => {
            'encounterDuoCodeReviewErrorDuringReviewEventCount' => nil,
            'findNoIssuesDuoCodeReviewAfterReviewEventCount' => nil,
            'findNothingToReviewDuoCodeReviewOnMrEventCount' => nil,
            'postCommentDuoCodeReviewOnDiffEventCount' => 99,
            'reactThumbsUpOnDuoCodeReviewCommentEventCount' => nil,
            'reactThumbsDownOnDuoCodeReviewCommentEventCount' => nil,
            'requestReviewDuoCodeReviewOnMrByAuthorEventCount' => nil,
            'requestReviewDuoCodeReviewOnMrByNonAuthorEventCount' => nil,
            'excludedFilesFromDuoCodeReviewEventCount' => nil
          },
          'chat' => {
            'requestDuoChatResponseEventCount' => nil
          },
          'troubleshoot' => {
            'troubleshootJobEventCount' => nil
          },
          'mcp' => {
            'startMcpToolCallEventCount' => nil,
            'finishMcpToolCallEventCount' => 5
          }
        }

        expect(ai_metrics).to eq(expected_results)
      end
    end

    context 'when filter range is too wide' do
      let(:filter_params) { { startDate: 5.years.ago } }

      it 'returns an error' do
        expect_graphql_errors_to_include("maximum date range is 1 year")
        expect(ai_metrics).to be_nil
      end
    end
  end

  context 'for group' do
    let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_metrics_fields) }
    let(:ai_metrics) { graphql_data['group']['aiMetrics'] }
    let_it_be(:namespace) { group }

    it_behaves_like 'common ai metrics'
  end

  context 'for project' do
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:namespace) { project.project_namespace }
    let(:query) { graphql_query_for(:project, { fullPath: project.full_path }, ai_metrics_fields) }
    let(:ai_metrics) { graphql_data['project']['aiMetrics'] }

    it_behaves_like 'common ai metrics'
  end
end
