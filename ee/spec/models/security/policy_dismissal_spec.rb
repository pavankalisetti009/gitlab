# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyDismissal, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:merge_request).required }
    it { is_expected.to belong_to(:security_policy).optional }
    it { is_expected.to belong_to(:user).optional }
  end

  describe 'validations' do
    subject(:policy_dismissal) { create(:policy_dismissal) }

    it { is_expected.to allow_value(nil).for(:security_findings_uuids) }
    it { is_expected.to validate_length_of(:comment).is_at_most(255).allow_nil }

    it { is_expected.to(validate_uniqueness_of(:merge_request_id).scoped_to(%i[security_policy_id])) }

    context 'when validating dismissal_types' do
      it 'is invalid if empty' do
        policy_dismissal.dismissal_types = []
        expect(policy_dismissal).not_to be_valid
        expect(policy_dismissal.errors[:dismissal_types]).to include(/must be an array with allowed values/)
      end

      it 'is invalid if includes unknown value' do
        policy_dismissal.dismissal_types = described_class::DISMISSAL_TYPES.values + [999]
        expect(policy_dismissal).not_to be_valid
        expect(policy_dismissal.errors[:dismissal_types]).to include(/must be an array with allowed values/)
      end

      it 'is valid if all values are allowed' do
        policy_dismissal.dismissal_types = described_class::DISMISSAL_TYPES.values.sample(2)
        expect(policy_dismissal).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.for_projects' do
      subject(:policy_dismissal_for_projects) { described_class.for_projects(projects) }

      let_it_be(:project) { create(:project) }
      let_it_be(:security_policy_dismissal) { create(:policy_dismissal, project: project) }
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_security_policy_dismissal) { create(:policy_dismissal, project: other_project) }

      context 'when querying for a single project' do
        let(:projects) { [project] }

        it 'returns dismissals for the given project' do
          expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal)
        end

        context 'with multiple dismissals for the same project' do
          let_it_be(:second_security_policy_dismissal) { create(:policy_dismissal, project: project) }

          it 'returns dismissals for the given project' do
            expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal,
              second_security_policy_dismissal)
          end
        end
      end

      context 'when querying for multiple projects' do
        let_it_be(:third_project) { create(:project) }
        let_it_be(:third_security_policy_dismissal) { create(:policy_dismissal, project: third_project) }

        let(:projects) { [project, other_project] }

        it 'returns dismissals for the given projects' do
          expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal,
            other_security_policy_dismissal)
        end

        context 'with multiple dismissals for the same project' do
          let_it_be(:second_security_policy_dismissal_project) { create(:policy_dismissal, project: project) }
          let_it_be(:second_security_policy_dismissal_other_project) do
            create(:policy_dismissal, project: other_project)
          end

          it 'returns dismissals for the given projects' do
            expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal,
              other_security_policy_dismissal,
              second_security_policy_dismissal_project,
              second_security_policy_dismissal_other_project)
          end
        end
      end
    end

    describe '.for_security_findings_uuids' do
      let_it_be(:dismissed_finding) { SecureRandom.uuid }
      let_it_be(:non_dismissed_finding) { SecureRandom.uuid }
      let_it_be(:dismissed_findings) { [dismissed_finding] }
      let_it_be(:uuids) { [dismissed_finding] }

      let_it_be(:security_policy_dismissal) { create(:policy_dismissal, security_findings_uuids: dismissed_findings) }

      subject(:policy_dismissal_for_uuids) { described_class.for_security_findings_uuids(uuids) }

      context 'when querying for a single UUID' do
        it 'returns dismissals that contain the finding UUID' do
          expect(policy_dismissal_for_uuids).to contain_exactly(security_policy_dismissal)
        end
      end

      context 'when querying for multiple UUIDs' do
        let_it_be(:other_dismissed_finding) { SecureRandom.uuid }
        let_it_be(:uuids) { [dismissed_finding, other_dismissed_finding] }

        context 'when the UUIDs were dismissed by the same policy' do
          let_it_be(:dismissed_findings) { [dismissed_finding, other_dismissed_finding] }

          it 'returns dismissals that contain the vulnerability finding UUIDs' do
            expect(policy_dismissal_for_uuids).to contain_exactly(security_policy_dismissal)
          end
        end

        context 'when the UUIDs were dismissed by different policies' do
          let_it_be(:other_security_policy_dismissal) do
            create(:policy_dismissal, security_findings_uuids: [other_dismissed_finding])
          end

          it 'returns dismissals that contain the vulnerability finding UUIDs' do
            expect(policy_dismissal_for_uuids).to contain_exactly(security_policy_dismissal,
              other_security_policy_dismissal)
          end
        end
      end
    end

    describe '.including_merge_request_and_user' do
      let_it_be(:policy_dismissal) { create(:policy_dismissal) }

      it 'includes user and merge_request associations' do
        result = described_class.including_merge_request_and_user

        expect(result).to include(policy_dismissal)

        expect(result.first.association(:user)).to be_loaded
        expect(result.first.association(:merge_request)).to be_loaded
      end
    end
  end

  describe '#applicable_for_all_violations?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:security_policy) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

    context 'when dismissal covers all violation finding UUIDs' do
      let_it_be(:violation_1) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: %w[uuid-1 uuid-2])
      end

      let_it_be(:violation_2) do
        create(:scan_result_policy_violation, :previous_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-3'])
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: %w[uuid-1 uuid-2 uuid-3 uuid-4])
      end

      it 'returns true when all violation finding UUIDs are covered' do
        expect(policy_dismissal.applicable_for_all_violations?).to be true
      end
    end

    context 'when dismissal does not cover all violation finding UUIDs' do
      let_it_be(:violation_1) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: %w[uuid-1 uuid-2])
      end

      let_it_be(:violation_2) do
        create(:scan_result_policy_violation, :previous_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-3'])
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: %w[uuid-1 uuid-2])
      end

      it 'returns false when some violation finding UUIDs are missing' do
        expect(policy_dismissal.applicable_for_all_violations?).to be false
      end
    end

    context 'when there are no violations' do
      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: ['uuid-1'])
      end

      it 'returns true when there are no violations to check' do
        expect(policy_dismissal.applicable_for_all_violations?).to be true
      end
    end

    context 'when there are violations for other security policies' do
      let_it_be(:other_security_policy) do
        create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 1)
      end

      let_it_be(:other_approval_policy_rule) { create(:approval_policy_rule, security_policy: other_security_policy) }

      let_it_be(:matching_violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-1'])
      end

      let_it_be(:different_policy_violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: other_approval_policy_rule,
          uuids: ['uuid-2'])
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: ['uuid-1'])
      end

      it 'only considers violations for the same security policy' do
        expect(policy_dismissal.applicable_for_all_violations?).to be true
      end
    end

    context 'when there are violations for other merge requests' do
      let_it_be(:different_mr) do
        create(:merge_request, target_project: project, source_project: project, source_branch: 'different-branch')
      end

      let_it_be(:matching_violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-1'])
      end

      let_it_be(:different_mr_violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: different_mr,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-2'])
      end

      let_it_be(:policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: ['uuid-1'])
      end

      it 'only considers violations for the same merge request' do
        expect(policy_dismissal.applicable_for_all_violations?).to be true
      end
    end

    context 'when dismissal has empty security findings UUIDs' do
      let_it_be(:violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule,
          uuids: ['uuid-1'])
      end

      let_it_be(:empty_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          security_policy: security_policy,
          security_findings_uuids: [])
      end

      it 'returns false when security_findings_uuids is empty and there are violations' do
        expect(empty_dismissal.applicable_for_all_violations?).to be false
      end
    end
  end

  describe '#applicable_for_findings?' do
    let_it_be(:policy_dismissal) do
      create(:policy_dismissal, security_findings_uuids: %w[uuid-1 uuid-2 uuid-3])
    end

    it 'returns true for subset of UUIDs' do
      expect(policy_dismissal.applicable_for_findings?(%w[uuid-1 uuid-2])).to be true
    end

    it 'returns true for exact match of UUIDs' do
      expect(policy_dismissal.applicable_for_findings?(%w[uuid-1 uuid-2 uuid-3])).to be true
    end

    it 'returns true for empty array' do
      expect(policy_dismissal.applicable_for_findings?([])).to be true
    end

    it 'returns false when some UUIDs are missing' do
      expect(policy_dismissal.applicable_for_findings?(%w[uuid-1 uuid-4])).to be false
    end

    context 'when dismissal has no security findings UUIDs' do
      let_it_be(:empty_dismissal) { create(:policy_dismissal, security_findings_uuids: []) }

      it 'returns false for any provided UUIDs' do
        expect(empty_dismissal.applicable_for_findings?(['uuid-1'])).to be false
      end

      it 'returns true for empty array' do
        expect(empty_dismissal.applicable_for_findings?([])).to be true
      end
    end
  end

  describe '#preserve!' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let(:policy_dismissal) { create(:policy_dismissal, project: project, merge_request: merge_request) }

    subject(:preserve) { policy_dismissal.preserve! }

    before do
      allow(Gitlab::EventStore).to receive(:publish)
    end

    context 'when dismissal is applicable for all violations' do
      before do
        allow(policy_dismissal).to receive(:applicable_for_all_violations?).and_return(true)
      end

      it 'changes status to preserved and publishes event', :aggregate_failures do
        expect { preserve }.to change { policy_dismissal.reload.status }.from(0).to(1)

        expect(Gitlab::EventStore).to have_received(:publish) do |event|
          expect(event).to be_a(Security::PolicyDismissalPreservedEvent)
          expect(event.data[:security_policy_dismissal_id]).to eq(policy_dismissal.id)
        end
      end
    end

    context 'when dismissal is not applicable for all violations' do
      before do
        allow(policy_dismissal).to receive(:applicable_for_all_violations?).and_return(false)
      end

      it 'destroys the dismissal instead of preserving it' do
        policy_dismissal.id

        expect { preserve }.to change { described_class.count }.by(-1)
      end

      it 'does not publish the preserved event when destroyed' do
        preserve

        expect(Gitlab::EventStore).not_to have_received(:publish)
      end
    end
  end
end
