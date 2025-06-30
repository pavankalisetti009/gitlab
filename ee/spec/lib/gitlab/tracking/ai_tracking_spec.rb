# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiTracking, feature_category: :value_stream_management do
  context 'for code suggestion events' do
    let(:expected_context) do
      { unique_tracking_id: '123', suggestion_size: 100, language: 'ruby', branch_name: 'feature' }
    end

    let(:sample_context) do
      expected_context.merge(something_extra: '123')
    end

    it 'has `shown` event registered' do
      is_expected.to have_ai_event_registered(code_suggestion_shown_in_ide: 2)
                       .with_transformation(sample_context => expected_context)
    end

    it 'has `accepted` event registered' do
      is_expected.to have_ai_event_registered(code_suggestion_accepted_in_ide: 3)
                       .with_transformation(sample_context => expected_context)
    end

    it 'has `rejected` event registered' do
      is_expected.to have_ai_event_registered(code_suggestion_rejected_in_ide: 4)
                       .with_transformation(sample_context => expected_context)
    end
  end

  context 'for duo chat events' do
    it { is_expected.to have_ai_event_registered(request_duo_chat_response: 6).with_no_transformations }
  end

  context 'for troubleshoot job events' do
    let_it_be(:merge_request) { create(:merge_request) }
    let_it_be(:pipeline) { create(:ci_pipeline, merge_request: merge_request) }
    let_it_be(:job) { create(:ci_build, pipeline: pipeline) }

    let(:sample_context) do
      { job: job }
    end

    let(:expected_context) do
      { job_id: job.id, project_id: job.project_id, pipeline_id: pipeline.id, merge_request_id: merge_request.id }
    end

    it 'has `troubleshoot_job` event registered' do
      is_expected.to have_ai_event_registered(troubleshoot_job: 7)
                       .with_transformation(sample_context => expected_context)
    end
  end
end
