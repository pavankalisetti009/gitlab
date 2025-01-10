# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Repositories::RepoType, feature_category: :source_code_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:personal_snippet) { create(:personal_snippet, author: project.first_owner) }
  let_it_be(:project_snippet) { create(:project_snippet, project: project, author: project.first_owner) }

  let(:project_path) { project.repository.full_path }
  let(:wiki_path) { project.wiki.repository.full_path }
  let(:design_path) { project.design_repository.full_path }
  let(:personal_snippet_path) { "snippets/#{personal_snippet.id}" }
  let(:project_snippet_path) { "#{project.full_path}/snippets/#{project_snippet.id}" }

  describe '.repository_for' do
    subject(:design_repository) { Gitlab::GlRepository::DESIGN }

    let(:expected_message) do
      "Expected container class to be #{subject.container_class} for " \
        "repo type #{design_repository.name}, but found #{project.class.name} instead."
    end

    it 'raises an error when container class does not match given container_class' do
      expect do
        design_repository.repository_for(project)
      end.to raise_error(Gitlab::Repositories::ContainerClassMismatchError, expected_message)
    end
  end
end
