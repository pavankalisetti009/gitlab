# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terraform::StateVersion, feature_category: :infrastructure_as_code do
  using RSpec::Parameterized::TableSyntax
  include EE::GeoHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe 'associations' do
    it do
      is_expected.to have_one(:terraform_state_version_state)
                       .class_name('Geo::TerraformStateVersionState')
                       .with_foreign_key(:terraform_state_version_id)
                       .inverse_of(:terraform_state_version)
    end
  end

  describe '.replicables_for_current_secondary' do
    where(:selective_sync_enabled, :object_storage_sync_enabled, :terraform_object_storage_enabled, :synced_states) do
      true  | true  | true  | 5
      true  | true  | false | 5
      true  | false | true  | 0
      true  | false | false | 5
      false | false | false | 10
      false | false | true  | 0
      false | true  | true  | 10
      false | true  | false | 10
      true  | true  | false | 5
    end

    with_them do
      let(:secondary) do
        node = build(:geo_node, sync_object_storage: object_storage_sync_enabled)

        if selective_sync_enabled
          node.selective_sync_type = 'namespaces'
          node.namespaces = [group]
        end

        node.save!
        node
      end

      before do
        stub_current_geo_node(secondary)
        stub_terraform_state_object_storage if terraform_object_storage_enabled

        create_list(:terraform_state_version, 5, terraform_state: create(:terraform_state, project: project))
        create_list(:terraform_state_version, 5, terraform_state: create(:terraform_state, project: create(:project)))
      end

      it 'returns the proper number of terraform states' do
        expect(described_class.replicables_for_current_secondary(1..described_class.last.id).count).to eq(synced_states)
      end
    end
  end

  describe '.search' do
    let_it_be(:state_version1) { create(:terraform_state_version) }
    let_it_be(:state_version2) { create(:terraform_state_version) }
    let_it_be(:state_version3) { create(:terraform_state_version) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(state_version1, state_version2, state_version3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all terraform state versions' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches by attributes' do
        context 'for file attribute' do
          before do
            state_version1.update_column(:file, '1.tfstate')
            state_version2.update_column(:file, '2.tfstate')
            state_version3.update_column(:file, '3.tfstate')
          end

          it do
            result = described_class.search('3')

            expect(result).to contain_exactly(state_version3)
          end
        end
      end
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:terraform_state_version_state)
          .class_name('Geo::TerraformStateVersionState')
          .inverse_of(:terraform_state_version)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) do
        build(:terraform_state_version, terraform_state: create(:terraform_state))
      end

      let(:unverifiable_model_record) do
        record = create(:terraform_state_version, terraform_state: create(:terraform_state))
        record.update_column(:file_store, ObjectStorage::Store::REMOTE)
        record
      end
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }

      # Terraform state version for the root group
      let!(:first_replicable_and_in_selective_sync) do
        stub_terraform_state_object_storage(enabled: false)
        create(:terraform_state_version, terraform_state: create(:terraform_state, project: project_1))
      end

      # Terraform state version for a subgroup
      let!(:second_replicable_and_in_selective_sync) do
        stub_terraform_state_object_storage(enabled: false)
        create(:terraform_state_version, terraform_state: create(:terraform_state, project: project_2))
      end

      # Terraform state version for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        stub_terraform_state_object_storage(enabled: true)
        create(:terraform_state_version, :object_storage, terraform_state: create(:terraform_state, project: project_1))
      end

      # Terraform state version for a group not in selective sync
      let!(:last_replicable_and_not_in_selective_sync) do
        stub_terraform_state_object_storage(enabled: false)
        create(:terraform_state_version, terraform_state: create(:terraform_state, project: project_3))
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
