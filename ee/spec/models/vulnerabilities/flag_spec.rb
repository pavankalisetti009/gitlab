# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Flag, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:finding).class_name('Vulnerabilities::Finding').with_foreign_key('vulnerability_occurrence_id').required }
    it { is_expected.to belong_to(:workflow).class_name('::Ai::DuoWorkflows::Workflow').optional }
  end

  describe 'validations' do
    subject { build(:vulnerabilities_flag) }

    it { is_expected.to validate_length_of(:origin).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(100000) }
    it { is_expected.to validate_presence_of(:flag_type) }
    it { is_expected.to validate_uniqueness_of(:flag_type).scoped_to(:vulnerability_occurrence_id, :origin).ignoring_case_sensitivity }
    it { is_expected.to validate_inclusion_of(:confidence_score).in_range(0.0..1.0) }
    it { is_expected.to define_enum_for(:flag_type).with_values(false_positive: 0) }
    it { is_expected.to define_enum_for(:status).with_values(described_class::FALSE_POSITIVE_DETECTION_STATUSES) }
  end

  describe '#initialize' do
    it 'creates a valid flag with flag_type attribute' do
      flag = described_class.new(flag_type: described_class.flag_types[:false_positive], origin: 'post analyzer X', description: 'static string to sink', finding: build(:vulnerabilities_finding))
      expect(flag).to be_valid
    end
  end

  context 'with loose foreign key on vulnerability_flags.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerabilities_flag, project_id: parent.id) }
    end
  end

  describe '.by_finding_id' do
    let!(:finding) { create(:vulnerabilities_finding) }
    let!(:vulnerability_flag) { create(:vulnerabilities_flag, finding: finding) }
    let!(:another_vulnerability_flag) { create(:vulnerabilities_flag) }

    subject { described_class.by_finding_id(finding.id) }

    it { is_expected.to contain_exactly(vulnerability_flag) }
  end

  describe 'after_commit callback for trigger_resolution_workflow' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:vulnerability) { create(:vulnerability, project: project, author: user) }
    let_it_be(:finding) { create(:vulnerabilities_finding, project: project, vulnerability: vulnerability) }

    context 'when a vulnerability flag gets created' do
      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(enable_vulnerability_resolution: false)
        end

        it 'does not trigger resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .not_to receive(:perform_async)

          create(:vulnerabilities_flag, finding: finding, confidence_score: 0.5, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
        end
      end

      context 'when feature flag is enabled' do
        context 'when origin is ai_sast_fp_detection' do
          context 'when confidence score is below threshold' do
            it 'triggers resolution workflow' do
              expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
                .to receive(:perform_async)
                      .with(anything)

              create(:vulnerabilities_flag, finding: finding, confidence_score: 0.5, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
            end
          end

          context 'when confidence score is at threshold' do
            it 'does not trigger resolution workflow' do
              expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
                .not_to receive(:perform_async)

              create(:vulnerabilities_flag, finding: finding, confidence_score: 0.6, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
            end
          end

          context 'when confidence score is above threshold' do
            it 'does not trigger resolution workflow' do
              expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
                .not_to receive(:perform_async)

              create(:vulnerabilities_flag, finding: finding, confidence_score: 0.8, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
            end
          end
        end

        context 'when origin is not ai_sast_fp_detection' do
          it 'does not trigger resolution workflow' do
            expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
              .not_to receive(:perform_async)

            create(:vulnerabilities_flag, finding: finding, confidence_score: 0.5, origin: 'some_other_origin')
          end
        end
      end
    end

    context 'when updating an existing vulnerability flag' do
      let_it_be(:existing_flag) { create(:vulnerabilities_flag, finding: finding, confidence_score: 0.5, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN) }

      context 'when only non-relevant fields are updated' do
        it 'does not trigger resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .not_to receive(:perform_async)

          existing_flag.update!(description: 'Updated description')
        end
      end

      context 'when confidence_score is updated' do
        it 'triggers resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .to receive(:perform_async)
                  .with(existing_flag.id)

          existing_flag.update!(confidence_score: 0.4)
        end
      end

      context 'when origin is updated to AI_SAST_FP_DETECTION_ORIGIN' do
        it 'triggers resolution workflow' do
          existing_flag.update!(origin: 'some_other_origin')

          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .to receive(:perform_async)
                  .with(existing_flag.id)

          existing_flag.update!(origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
        end
      end

      context 'when origin changes to non-ai origin' do
        it 'does not trigger resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .not_to receive(:perform_async)

          existing_flag.update!(origin: 'some_other_origin')
        end
      end

      context 'when confidence score changes to above threshold' do
        it 'does not trigger resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .not_to receive(:perform_async)

          existing_flag.update!(confidence_score: 0.8)
        end
      end
    end
  end
end
