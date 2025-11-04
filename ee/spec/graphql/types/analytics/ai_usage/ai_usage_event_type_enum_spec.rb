# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiUsage::AiUsageEventTypeEnum, feature_category: :value_stream_management do
  it 'includes a value for each usage event type' do
    expect(described_class.values).to match(
      'CODE_SUGGESTIONS_REQUESTED' => have_attributes(value: 'code_suggestions_requested'),
      'CODE_SUGGESTION_ACCEPTED_IN_IDE' => have_attributes(value: 'code_suggestion_accepted_in_ide'),
      'CODE_SUGGESTION_REJECTED_IN_IDE' => have_attributes(value: 'code_suggestion_rejected_in_ide'),
      'CODE_SUGGESTION_DIRECT_ACCESS_TOKEN_REFRESH' => have_attributes(
        value: 'code_suggestion_direct_access_token_refresh'
      ),
      'CODE_SUGGESTION_SHOWN_IN_IDE' => have_attributes(value: 'code_suggestion_shown_in_ide'),
      'REQUEST_DUO_CHAT_RESPONSE' => have_attributes(value: 'request_duo_chat_response'),
      'TROUBLESHOOT_JOB' => have_attributes(value: 'troubleshoot_job'),
      'ENCOUNTER_DUO_CODE_REVIEW_ERROR_DURING_REVIEW' => have_attributes(
        value: 'encounter_duo_code_review_error_during_review'
      ),
      'FIND_NO_ISSUES_DUO_CODE_REVIEW_AFTER_REVIEW' => have_attributes(
        value: 'find_no_issues_duo_code_review_after_review'),
      'FIND_NOTHING_TO_REVIEW_DUO_CODE_REVIEW_ON_MR' => have_attributes(
        value: 'find_nothing_to_review_duo_code_review_on_mr'
      ),
      'POST_COMMENT_DUO_CODE_REVIEW_ON_DIFF' => have_attributes(
        value: 'post_comment_duo_code_review_on_diff'
      ),
      'REACT_THUMBS_UP_ON_DUO_CODE_REVIEW_COMMENT' => have_attributes(
        value: 'react_thumbs_up_on_duo_code_review_comment'
      ),
      'REACT_THUMBS_DOWN_ON_DUO_CODE_REVIEW_COMMENT' => have_attributes(
        value: 'react_thumbs_down_on_duo_code_review_comment'
      ),
      'REQUEST_REVIEW_DUO_CODE_REVIEW_ON_MR_BY_AUTHOR' => have_attributes(
        value: 'request_review_duo_code_review_on_mr_by_author'
      ),
      'REQUEST_REVIEW_DUO_CODE_REVIEW_ON_MR_BY_NON_AUTHOR' => have_attributes(
        value: 'request_review_duo_code_review_on_mr_by_non_author'
      ),
      'EXCLUDED_FILES_FROM_DUO_CODE_REVIEW' => have_attributes(
        value: 'excluded_files_from_duo_code_review'
      ),
      'AGENT_PLATFORM_SESSION_CREATED' => have_attributes(value: 'agent_platform_session_created'),
      'AGENT_PLATFORM_SESSION_STARTED' => have_attributes(value: 'agent_platform_session_started'),
      'AGENT_PLATFORM_SESSION_FINISHED' => have_attributes(value: 'agent_platform_session_finished'),
      'AGENT_PLATFORM_SESSION_DROPPED' => have_attributes(value: 'agent_platform_session_dropped'),
      'AGENT_PLATFORM_SESSION_STOPPED' => have_attributes(value: 'agent_platform_session_stopped'),
      'AGENT_PLATFORM_SESSION_RESUMED' => have_attributes(value: 'agent_platform_session_resumed')
    )
  end
end
