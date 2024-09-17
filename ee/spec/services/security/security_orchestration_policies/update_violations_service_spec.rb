# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::UpdateViolationsService, feature_category: :security_policy_management do
  let(:service) { described_class.new(merge_request, :scan_finding) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request, reload: true) do
    create(:merge_request, source_project: project, target_project: project)
  end

  let_it_be(:policy_a) { create(:scan_result_policy_read, project: project) }
  let_it_be(:policy_b) { create(:scan_result_policy_read, project: project) }
  let(:violated_policies) { violations.map(&:scan_result_policy_read) }

  subject(:violations) { merge_request.scan_result_policy_violations }

  def last_violation
    violations.last.reload
  end

  describe '#execute' do
    describe 'attributes' do
      subject(:attrs) { project.scan_result_policy_violations.last.attributes }

      before do
        service.add([policy_b.id], [])
        service.execute
      end

      specify do
        is_expected.to include(
          "scan_result_policy_id" => kind_of(Numeric),
          "merge_request_id" => kind_of(Numeric),
          "project_id" => kind_of(Numeric))
      end
    end

    context 'without pre-existing violations' do
      before do
        service.add([policy_b.id], [])
      end

      it 'creates violations' do
        service.execute

        expect(violated_policies).to contain_exactly(policy_b)
      end

      it 'stores the correct status' do
        service.add_violation(policy_b.id, { uuid: { newly_detected: [123] } })
        service.execute

        expect(last_violation.status).to eq("completed")
        expect(last_violation).to be_valid
      end

      it 'can persist violation data' do
        service.add_violation(policy_b.id, { uuid: { newly_detected: [123] } })
        service.execute

        expect(last_violation.violation_data)
          .to eq({ "violations" => { "scan_finding" => { "uuid" => { "newly_detected" => [123] } } } })
        expect(last_violation).to be_valid
      end
    end

    context 'with pre-existing violations' do
      before do
        service.add_violation(policy_a.id, { uuids: { newly_detected: [123] } })
        service.execute
      end

      it 'clears existing violations' do
        service.add([policy_b.id], [policy_a.id])
        service.execute

        expect(violated_policies).to contain_exactly(policy_b)
      end

      it 'can add error to existing violation data' do
        service.add_error(policy_a.id, :scan_removed, missing_scans: ['sast'])

        expect { service.execute }
          .to change { last_violation.violation_data }.to match(
            { 'violations' => { 'scan_finding' => { 'uuids' => { 'newly_detected' => [123] } } },
              'errors' => [{ 'error' => 'SCAN_REMOVED', 'missing_scans' => ['sast'] }] }
          )
        expect(last_violation).to be_valid
      end

      it 'stores the correct status' do
        service.add_error(policy_a.id, :scan_removed, missing_scans: ['sast'])
        service.execute

        expect(last_violation.status).to eq("completed")
        expect(last_violation).to be_valid
      end

      context 'with identical state' do
        it 'does not clear violations' do
          service.add([policy_a.id], [])

          expect { service.execute }.not_to change { last_violation.violation_data }
          expect(violated_policies).to contain_exactly(policy_a)
          expect(last_violation).to be_valid
        end
      end
    end

    context 'with unrelated existing violation' do
      let_it_be(:unrelated_violation) do
        create(:scan_result_policy_violation, scan_result_policy_read: policy_a, merge_request: merge_request)
      end

      before do
        service.add([], [policy_b.id])
      end

      it 'removes only violations provided in unviolated ids' do
        service.execute

        expect(violations).to contain_exactly(unrelated_violation)
      end
    end

    context 'without violations' do
      it 'clears all violations' do
        service.execute

        expect(violations).to be_empty
      end
    end
  end

  describe '#add_violation' do
    subject(:violation_data) do
      service.add_violation(policy_a.id, data, context: context)
      service.violation_data[policy_a.id]
    end

    let(:context) { nil }
    let(:data) { { uuid: { newly_detected: [123] } } }

    it 'adds violation data into the correct structure' do
      expect(violation_data)
        .to eq({ violations: { scan_finding: { uuid: { newly_detected: [123] } } } })
    end

    it 'stores the correct status' do
      service.add_error(policy_a.id, :scan_removed, missing_scans: ['sast'])
      service.execute

      expect(last_violation.status).to eq("completed")
      expect(last_violation).to be_valid
    end

    context 'when other data is present' do
      before do
        service.add_violation(policy_a.id, { uuid: { previously_existing: [456] } })
      end

      it 'merges the data for report_type' do
        expect(violation_data)
          .to eq({ violations: { scan_finding: { uuid: { previously_existing: [456], newly_detected: [123] } } } })
      end
    end

    context 'with additional context' do
      let(:context) { { pipeline_ids: [1] } }

      it 'saves context information' do
        expect(violation_data)
          .to match({
            context: { pipeline_ids: [1] },
            violations: { scan_finding: { uuid: { newly_detected: [123] } } }
          })
      end
    end
  end

  describe '#add_error' do
    subject(:violation_data) do
      service.add_error(policy_a.id, error, **extra_data)
      service.violation_data[policy_a.id]
    end

    let(:error) { :scan_removed }
    let(:extra_data) { {} }

    it 'adds error into violation data' do
      expect(violation_data)
        .to eq({ errors: [{ error: 'SCAN_REMOVED' }] })
    end

    context 'when other error is present' do
      before do
        service.add_error(policy_a.id, :artifacts_missing)
      end

      it 'merges the errors' do
        expect(violation_data)
          .to match({ errors: array_including({ error: 'SCAN_REMOVED' }, { error: 'ARTIFACTS_MISSING' }) })
      end
    end

    context 'with extra data' do
      let(:extra_data) { { missing_scans: ['sast'] } }

      it 'saves extra data' do
        expect(violation_data)
          .to eq({ errors: [{ error: 'SCAN_REMOVED', missing_scans: ['sast'] }] })
      end
    end
  end
end
