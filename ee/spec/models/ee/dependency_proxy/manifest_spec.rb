# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyProxy::Manifest, feature_category: :geo_replication do
  describe 'Geo replication' do
    before do
      stub_dependency_proxy_setting(enabled: true)
      stub_dependency_proxy_object_storage
    end

    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:dependency_proxy_manifest_state)
          .class_name('Geo::DependencyProxyManifestState')
          .inverse_of(:dependency_proxy_manifest)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) { build(:dependency_proxy_manifest) }
      let(:unverifiable_model_record) { build(:dependency_proxy_manifest, :remote_store) }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }

      # Manifest for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        create(:dependency_proxy_manifest, group: group_1)
      end

      # Manifest for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        create(:dependency_proxy_manifest, group: nested_group_1)
      end

      # Manifest for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        create(:dependency_proxy_manifest, :remote_store, group: group_1)
      end

      # Manifest for a group not in selective sync
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        create(:dependency_proxy_manifest, group: group_2)
      end

      let_it_be_with_refind(:secondary) { create(:geo_node, :secondary) }

      before do
        stub_current_geo_node(secondary)
      end

      describe '.replicables_for_current_secondary' do
        include_examples 'Geo framework selective sync scenarios', :replicables_for_current_secondary
      end

      describe '.selective_sync_scope' do
        include_examples 'Geo framework selective sync scenarios', :selective_sync_scope

        it 'raises if an unrecognised selective sync type is used' do
          secondary.update_attribute(:selective_sync_type, 'unknown')

          expect { described_class.selective_sync_scope(secondary) }
            .to raise_error(Geo::Errors::UnknownSelectiveSyncType)
        end
      end

      describe '.verifiables' do
        include_examples 'Geo framework selective sync scenarios', :verifiables
      end
    end
  end
end
