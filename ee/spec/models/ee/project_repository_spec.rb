# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectRepository, feature_category: :source_code_management do
  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:project_repository_state)
          .class_name('Geo::ProjectRepositoryState')
          .inverse_of(:project_repository)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:skip_unverifiable_model_record_tests) { true }

      let(:verifiable_model_record) { build(:project_repository) }
      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }

      # Project for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        project = create(:project_with_repo, group: group_1)
        project.project_repository
      end

      # Project for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        project = create(:project_with_repo, group: nested_group_1)
        project.project_repository
      end

      # Project in a shard name that doesn't actually exist
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        project = create(:project_with_repo, :broken_storage, group: group_2)
        project.project_repository
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
