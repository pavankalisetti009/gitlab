# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe CleanupFuzzTestingComplianceControls, feature_category: :compliance_management do
  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:compliance_frameworks) { table(:compliance_management_frameworks) }
  let(:compliance_requirements) { table(:compliance_requirements) }
  let(:compliance_requirements_controls) { table(:compliance_requirements_controls) }

  let!(:organization) { organizations.create!(name: 'organization', path: 'organization') }
  let!(:namespace) do
    namespaces.create!(name: 'namespace', path: 'namespace', type: 'Group', organization_id: organization.id)
  end

  let!(:framework) do
    compliance_frameworks.create!(
      namespace_id: namespace.id,
      name: 'Test Framework',
      description: 'Test Description',
      color: '#000000'
    )
  end

  let!(:requirement) do
    compliance_requirements.create!(
      namespace_id: namespace.id,
      framework_id: framework.id,
      name: 'Test Requirement',
      description: 'Test Description'
    )
  end

  # scanner_fuzz_testing_running has enum_value: 13
  let!(:fuzz_testing_control) do
    compliance_requirements_controls.create!(
      namespace_id: namespace.id,
      compliance_requirement_id: requirement.id,
      name: 13, # scanner_fuzz_testing_running
      control_type: 0, # internal
      expression: { operator: '=', field: 'scanner_fuzz_testing_running', value: true }.to_json
    )
  end

  # scanner_sast_running has enum_value: 0
  let!(:sast_control) do
    compliance_requirements_controls.create!(
      namespace_id: namespace.id,
      compliance_requirement_id: requirement.id,
      name: 0, # scanner_sast_running
      control_type: 0, # internal
      expression: { operator: '=', field: 'scanner_sast_running', value: true }.to_json
    )
  end

  # scanner_dast_running has enum_value: 11
  let!(:dast_control) do
    compliance_requirements_controls.create!(
      namespace_id: namespace.id,
      compliance_requirement_id: requirement.id,
      name: 11, # scanner_dast_running
      control_type: 0, # internal
      expression: { operator: '=', field: 'scanner_dast_running', value: true }.to_json
    )
  end

  # External control
  let!(:external_control) do
    compliance_requirements_controls.create!(
      namespace_id: namespace.id,
      compliance_requirement_id: requirement.id,
      name: 10000, # external_control
      control_type: 1, # external
      external_control_name: 'External Control',
      external_url: 'https://example.com'
    )
  end

  describe '#up' do
    it 'removes only fuzz testing compliance controls' do
      expect { migrate! }.to change { compliance_requirements_controls.count }.from(4).to(3)

      expect(compliance_requirements_controls.pluck(:id)).to contain_exactly(
        sast_control.id,
        dast_control.id,
        external_control.id
      )
    end

    it 'does not remove other scanner controls' do
      migrate!

      expect(compliance_requirements_controls.find_by(id: sast_control.id)).to be_present
      expect(compliance_requirements_controls.find_by(id: dast_control.id)).to be_present
    end

    it 'does not remove external controls' do
      migrate!

      expect(compliance_requirements_controls.find_by(id: external_control.id)).to be_present
    end

    it 'removes fuzz testing control' do
      migrate!

      expect(compliance_requirements_controls.find_by(id: fuzz_testing_control.id)).to be_nil
    end

    context 'when there are no fuzz testing controls' do
      before do
        compliance_requirements_controls.where(name: 13).delete_all
      end

      it 'does not remove any records' do
        expect { migrate! }.not_to change { compliance_requirements_controls.count }
      end
    end

    context 'when there are multiple fuzz testing controls' do
      let!(:requirement_2) do
        compliance_requirements.create!(
          namespace_id: namespace.id,
          framework_id: framework.id,
          name: 'Test Requirement 2',
          description: 'Test Description 2'
        )
      end

      let!(:fuzz_testing_control_2) do
        compliance_requirements_controls.create!(
          namespace_id: namespace.id,
          compliance_requirement_id: requirement_2.id,
          name: 13, # scanner_fuzz_testing_running
          control_type: 0, # internal
          expression: { operator: '=', field: 'scanner_fuzz_testing_running', value: true }.to_json
        )
      end

      it 'removes all fuzz testing controls' do
        expect { migrate! }.to change { compliance_requirements_controls.count }.from(5).to(3)

        expect(compliance_requirements_controls.find_by(id: fuzz_testing_control.id)).to be_nil
        expect(compliance_requirements_controls.find_by(id: fuzz_testing_control_2.id)).to be_nil
      end
    end
  end

  describe '#down' do
    it 'is a no-op and does not restore deleted records' do
      migrate!

      expect(compliance_requirements_controls.find_by(id: fuzz_testing_control.id)).to be_nil

      schema_migrate_down!

      expect(compliance_requirements_controls.find_by(id: fuzz_testing_control.id)).to be_nil
      expect(compliance_requirements_controls.count).to eq(3)
    end
  end
end
