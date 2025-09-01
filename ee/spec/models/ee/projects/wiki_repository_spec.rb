# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::WikiRepository, feature_category: :wiki do
  describe 'Geo', feature_category: :geo_replication do
    describe 'associations' do
      it do
        is_expected
          .to have_one(:wiki_repository_state)
          .class_name('Geo::WikiRepositoryState')
          .inverse_of(:project_wiki_repository)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) { build(:project_wiki_repository) }
      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, :broken_storage, group: group_2) }

      # Wiki for the root group
      let_it_be(:first_replicable_and_in_selective_sync) { create(:project_wiki_repository, project: project_1) }
      # Wiki for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) { create(:project_wiki_repository, project: project_2) }
      # Wiki in a shard name that doesn't actually exist
      let_it_be(:last_replicable_and_not_in_selective_sync) { create(:project_wiki_repository, project: project_3) }

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
