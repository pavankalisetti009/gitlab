# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::WikiRepositoryState, type: :model, feature_category: :geo_replication do
  subject { described_class.new(project_wiki_repository: build(:project_wiki_repository)) }

  describe 'associations' do
    it {
      is_expected
        .to belong_to(:project_wiki_repository)
              .class_name('Projects::WikiRepository')
              .inverse_of(:wiki_repository_state)
    }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project_wiki_repository) }
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_uniqueness_of(:project_wiki_repository) }
    it { is_expected.to validate_length_of(:verification_failure).is_at_most(255) }
  end

  context 'with loose foreign key on wiki_repository_states.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:geo_wiki_repository_state, project_id: parent.id) }
    end
  end

  context 'with loose foreign key on wiki_repository_states.project_wiki_repository_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project_wiki_repository) }
      let_it_be(:model) { create(:geo_wiki_repository_state, project_wiki_repository: parent) }
    end
  end
end
