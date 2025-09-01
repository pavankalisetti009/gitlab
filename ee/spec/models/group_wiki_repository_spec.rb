# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupWikiRepository, feature_category: :wiki do
  describe 'associations' do
    it { is_expected.to belong_to(:shard) }
    it { is_expected.to belong_to(:group) }
  end

  context 'with loose foreign key on group_wiki_repositories.group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:group_wiki_repository, group: parent) }
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:shard) }
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:disk_path) }

    context 'uniqueness' do
      subject { described_class.new(shard: build(:shard), group: build(:group), disk_path: 'path') }

      it { is_expected.to validate_uniqueness_of(:group) }
      it { is_expected.to validate_uniqueness_of(:disk_path) }
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:group_wiki_repository_state)
          .class_name('Geo::GroupWikiRepositoryState')
          .inverse_of(:group_wiki_repository)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let_it_be(:group) { create(:group) }

      let(:verifiable_model_record) { build(:group_wiki_repository, group: group) }
      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }

      # Wiki for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        create(:group_wiki_repository, group: group_1)
      end

      # Wiki for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        create(:group_wiki_repository, group: nested_group_1)
      end

      # Wiki in a shard name that doesn't actually exist
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        create(:group_wiki_repository, group: group_2, shard_name: 'broken')
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
