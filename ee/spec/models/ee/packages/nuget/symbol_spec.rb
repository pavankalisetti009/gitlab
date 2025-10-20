# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Nuget::Symbol, feature_category: :geo_replication do
  include_examples 'a verifiable model for verification state' do
    let(:verifiable_model_record) { build(:nuget_symbol, object_storage_key: 'key') }
    let(:unverifiable_model_record) { nil }
  end

  describe 'scopes' do
    describe '.project_id_in' do
      let_it_be(:project) { create(:project) }
      let_it_be(:other_project) { create(:project) }
      let_it_be(:nuget_symbol) { create(:nuget_symbol, project:) }
      let_it_be(:other_nuget_symbol) { create(:nuget_symbol, project: other_project) }

      subject { described_class.project_id_in([project.id]) }

      it { is_expected.to contain_exactly(nuget_symbol) }
    end
  end

  describe '.replicables_for_current_secondary' do
    include ::EE::GeoHelpers

    subject(:replicables) { described_class.replicables_for_current_secondary(1..described_class.last.id) }

    context 'for replication' do
      let_it_be(:secondary) { create(:geo_node) }
      let_it_be(:nuget_symbol) { create(:nuget_symbol) }

      before do
        stub_current_geo_node(secondary)
      end

      it { is_expected.to be_an(ActiveRecord::Relation).and include(nuget_symbol) }
    end

    context 'for object storage' do
      before do
        stub_current_geo_node(secondary)
        stub_nuget_symbol_object_storage
      end

      let_it_be(:local_stored) { create(:nuget_symbol) }
      # Cannot use let_it_be because it depends on stub_nuget_symbol_object_storage
      let!(:object_stored) { create(:nuget_symbol, :object_storage) }

      context 'with sync object storage enabled' do
        let_it_be(:secondary) { create(:geo_node, sync_object_storage: true) }

        it { is_expected.to include(local_stored, object_stored) }
      end

      context 'with sync object storage disabled' do
        let_it_be(:secondary) { create(:geo_node, sync_object_storage: false) }

        it { is_expected.to include(local_stored).and exclude(object_stored) }
      end
    end

    context 'for selective sync' do
      # Create a nuget symbol owned by a project on shard foo
      let_it_be(:project_on_shard_foo) { create_project_on_shard('foo') }
      let_it_be(:package_on_shard_foo) do
        create(:nuget_package, without_package_files: true, project: project_on_shard_foo)
      end

      let_it_be(:nuget_symbol_on_shard_foo) do
        create(:nuget_symbol, package: package_on_shard_foo, project: project_on_shard_foo)
      end

      # Create a nuget symbol owned by a project on shard bar
      let_it_be(:project_on_shard_bar) { create_project_on_shard('bar') }
      let_it_be(:package_on_shard_bar) do
        create(:nuget_package, without_package_files: true, project: project_on_shard_bar)
      end

      let_it_be(:nuget_symbol_on_shard_bar) do
        create(:nuget_symbol, package: package_on_shard_bar, project: project_on_shard_bar)
      end

      # Create a nuget symbol owned by a particular namespace, and create
      # another nuget symbol owned via a nested group.
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: root_group) }
      let_it_be(:project_in_root_group) { create(:project, group: root_group) }
      let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
      let_it_be(:package_in_root_group) do
        create(:nuget_package, without_package_files: true, project: project_in_root_group)
      end

      let_it_be(:package_in_subgroup) do
        create(:nuget_package, without_package_files: true, project: project_in_subgroup)
      end

      let_it_be(:nuget_symbol_in_root_group) do
        create(:nuget_symbol, package: package_in_root_group, project: project_in_root_group)
      end

      let_it_be(:nuget_symbol_in_subgroup) do
        create(:nuget_symbol, package: package_in_subgroup, project: project_in_subgroup)
      end

      before do
        stub_current_geo_node(secondary)
      end

      context 'without selective sync' do
        let_it_be(:secondary) { create(:geo_node) }

        it 'does not exclude any records' do
          is_expected.to include(
            nuget_symbol_on_shard_foo,
            nuget_symbol_on_shard_bar,
            nuget_symbol_in_root_group,
            nuget_symbol_in_subgroup
          )
        end
      end

      context 'with selective sync by shard' do
        let_it_be(:secondary) { create(:geo_node, selective_sync_type: 'shards', selective_sync_shards: ['foo']) }

        it { is_expected.to include(nuget_symbol_on_shard_foo).and exclude(nuget_symbol_on_shard_bar) }
      end

      context 'with selective sync by namespace' do
        context 'with sync object storage enabled' do
          let_it_be(:secondary) { create(:geo_node, selective_sync_type: 'namespaces', namespaces: [root_group]) }

          it 'includes records owned by projects on a selected namespace' do
            is_expected.to include(nuget_symbol_in_root_group, nuget_symbol_in_subgroup)
              .and exclude(nuget_symbol_on_shard_foo, nuget_symbol_on_shard_bar)
          end
        end

        # The most complex permutation
        context 'with sync object storage disabled' do
          let_it_be(:secondary) do
            create(:geo_node, selective_sync_type: 'namespaces', namespaces: [root_group], sync_object_storage: false)
          end

          it 'includes only locally stored records owned by projects on a selected namespace' do
            is_expected.to include(nuget_symbol_in_root_group, nuget_symbol_in_subgroup)
              .and exclude(nuget_symbol_on_shard_foo, nuget_symbol_on_shard_bar)
          end

          context 'with object stored records' do
            before do
              nuget_symbol_in_root_group.update_column(:file_store, ObjectStorage::Store::REMOTE)
              nuget_symbol_in_subgroup.update_column(:file_store, ObjectStorage::Store::REMOTE)
            end

            it { is_expected.to exclude(nuget_symbol_in_root_group, nuget_symbol_in_subgroup) }
          end
        end
      end
    end
  end
end
