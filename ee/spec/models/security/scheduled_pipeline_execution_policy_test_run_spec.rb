# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScheduledPipelineExecutionPolicyTestRun, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:security_policy).class_name('Security::Policy') }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:pipeline).class_name('Ci::Pipeline').optional }
  end

  describe 'validations' do
    let(:test_run) { build(:security_pipeline_execution_policy_test_run) }

    subject { test_run }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:security_policy) }
    it { is_expected.to validate_presence_of(:project) }

    context 'when security policy is not a pipeline_execution_schedule_policy' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_policy) }
      let(:test_run) { build(:security_pipeline_execution_policy_test_run, security_policy: security_policy) }

      it { is_expected.not_to be_valid }
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:state).with_values(running: 0, complete: 1, failed: 2).with_default(:running) }
  end

  describe 'delegations' do
    let(:test_run) { create(:security_pipeline_execution_policy_test_run) }

    describe '#started_at' do
      it 'delegates to pipeline' do
        expect(test_run.started_at).to eq(test_run.pipeline.started_at)
      end
    end

    describe '#finished_at' do
      it 'delegates to pipeline' do
        expect(test_run.finished_at).to eq(test_run.pipeline.finished_at)
      end
    end

    describe '#duration' do
      it 'delegates to pipeline' do
        expect(test_run.duration).to eq(test_run.pipeline.duration)
      end
    end

    context 'when pipeline is nil' do
      let(:test_run) { create(:security_pipeline_execution_policy_test_run, pipeline: nil) }

      it 'returns nil for started_at' do
        expect(test_run.started_at).to be_nil
      end

      it 'returns nil for finished_at' do
        expect(test_run.finished_at).to be_nil
      end

      it 'returns nil for duration' do
        expect(test_run.duration).to be_nil
      end
    end
  end

  describe 'state transitions' do
    let(:test_run) { create(:security_pipeline_execution_policy_test_run, state: :running) }

    it 'starts in running state' do
      expect(test_run).to be_running
    end

    it 'can transition to complete' do
      test_run.update!(state: :complete)
      expect(test_run).to be_complete
    end

    it 'can transition to failed' do
      test_run.update!(state: :failed)
      expect(test_run).to be_failed
    end
  end

  describe 'error_message' do
    let(:test_run) { create(:security_pipeline_execution_policy_test_run, error_message: 'Test error') }

    it 'stores error message' do
      expect(test_run.error_message).to eq('Test error')
    end

    context 'when error_message exceeds limit' do
      let(:long_message) { 'a' * 256 }

      it 'truncates to 255 characters' do
        test_run = create(:security_pipeline_execution_policy_test_run, error_message: long_message)
        expect(test_run.error_message.length).to eq(255)
      end
    end
  end
end
