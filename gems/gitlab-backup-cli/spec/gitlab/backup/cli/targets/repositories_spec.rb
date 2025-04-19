# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Backup::Cli::Targets::Repositories do
  let(:context) { build_test_context }
  let(:gitaly_backup) { repo_target.gitaly_backup }

  subject(:repo_target) { described_class.new(context) }

  before do
    Gitlab::Backup::Cli::Models::Base.initialize_connection!(context: context)
  end

  describe '#dump' do
    it 'starts and finishes the gitaly_backup' do
      expect(gitaly_backup).to receive(:start).with(:create, '/path/to/destination')
      expect(repo_target).to receive(:enqueue_consecutive)
      expect(gitaly_backup).to receive(:finish!)

      repo_target.dump('/path/to/destination')
    end
  end

  describe '#restore' do
    it 'starts and finishes the gitaly_backup' do
      expect(gitaly_backup).to receive(:start)
                                 .with(:restore, '/path/to/destination', remove_all_repositories: ["default"])
      expect(repo_target).to receive(:enqueue_consecutive)
      expect(gitaly_backup).to receive(:finish!)
      expect(repo_target).to receive(:restore_object_pools)

      repo_target.restore('/path/to/destination')
    end
  end

  describe '#enqueue_consecutive' do
    it 'calls each resource respective enqueue methods', :aggregate_failures do
      expect(repo_target).to receive(:enqueue_consecutive_projects_source_code)
      expect(repo_target).to receive(:enqueue_consecutive_projects_wiki)
      expect(repo_target).to receive(:enqueue_consecutive_groups_wiki)
      expect(repo_target).to receive(:enqueue_consecutive_project_design_management)
      expect(repo_target).to receive(:enqueue_consecutive_project_snippets)
      expect(repo_target).to receive(:enqueue_consecutive_personal_snippets)

      repo_target.send(:enqueue_consecutive)
    end
  end

  describe '#enqueue_project_source_code' do
    let(:project) { object_double(Gitlab::Backup::Cli::Models::Project.new) }

    it 'enqueues project repository' do
      expect(gitaly_backup).to receive(:enqueue).with(project, Gitlab::Backup::Cli::RepoType::PROJECT)

      repo_target.send(:enqueue_project_source_code, project)
    end
  end

  describe '#enqueue_wiki' do
    let(:project) { object_double(Gitlab::Backup::Cli::Models::ProjectWiki.new) }

    it 'enqueues wiki repository' do
      expect(gitaly_backup).to receive(:enqueue).with(project, Gitlab::Backup::Cli::RepoType::WIKI)

      repo_target.send(:enqueue_wiki, project)
    end
  end

  describe '#enqueue_project_design_management' do
    let(:design_management) { object_double(Gitlab::Backup::Cli::Models::ProjectDesignManagement.new) }

    it 'enqueues design management repository' do
      expect(gitaly_backup).to receive(:enqueue).with(design_management, Gitlab::Backup::Cli::RepoType::DESIGN)

      repo_target.send(:enqueue_project_design_management, design_management)
    end
  end

  describe '#enqueue_snippet' do
    let(:snippet) { object_double(Gitlab::Backup::Cli::Models::ProjectSnippet.new) }

    it 'enqueues the snippet' do
      expect(gitaly_backup).to receive(:enqueue).with(snippet, Gitlab::Backup::Cli::RepoType::SNIPPET)

      repo_target.send(:enqueue_snippet, snippet)
    end
  end
end
