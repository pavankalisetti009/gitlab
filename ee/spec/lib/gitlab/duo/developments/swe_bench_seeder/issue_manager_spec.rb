# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::SweBenchSeeder::IssueManager, feature_category: :duo_chat do
  let(:project) { instance_double(Project) }
  let(:user) { instance_double(User) }
  let(:base_commit) { 'abc123def456' }
  let(:issue) { instance_double(Issue, iid: 1, title: 'Test Issue') }
  let(:issues_relation) { double }
  let(:projects_relation) { double }

  describe '.create_issue_from_problem_statement' do
    let(:problem_statement) do
      "Fix the login bug\n\nThe login page is broken when using special characters in passwords."
    end

    let(:created_issue) { instance_double(Issue, iid: 1, title: 'Fix the login bug', description: 'Test') }
    let(:service_response) { ServiceResponse.success(payload: { issue: created_issue }) }

    subject(:create_issue) do
      described_class.create_issue_from_problem_statement(project, user, problem_statement, base_commit)
    end

    before do
      allow(project).to receive(:issues).and_return(issues_relation)
      allow(issues_relation).to receive(:find_by_title).and_return(nil)
      allow(::Issues::CreateService).to receive(:new).and_return(instance_double(::Issues::CreateService,
        execute: service_response))
      # rubocop:disable RSpec/VerifiedDoubles -- UrlHelpers is a module, not a class
      allow(Rails.application.routes).to receive(:url_helpers).and_return(double(
        project_issue_url: 'http://example.com/issue/1'))
      # rubocop:enable RSpec/VerifiedDoubles
      allow(described_class).to receive(:create_issue_branch)
    end

    context 'when problem statement is valid' do
      it 'creates an issue with correct title and appends base commit' do
        expect(::Issues::CreateService).to receive(:new).with(
          container: project,
          current_user: user,
          params: hash_including(
            title: 'Fix the login bug',
            description: include("**To reproduce this issue, checkout the commit:** `#{base_commit}`")
          )
        ).and_return(instance_double(::Issues::CreateService, execute: service_response))

        result = create_issue

        expect(result).to eq(created_issue)
      end

      it 'creates issue branches' do
        expect(described_class).to receive(:create_issue_branch).with(project, created_issue, base_commit, user)

        create_issue
      end
    end

    context 'when problem statement is blank or nil' do
      it 'returns nil without creating an issue' do
        result = described_class.create_issue_from_problem_statement(project, user, '', base_commit)
        expect(result).to be_nil

        result = described_class.create_issue_from_problem_statement(project, user, nil, base_commit)
        expect(result).to be_nil
      end
    end

    context 'when base_commit is not provided' do
      subject(:create_issue) do
        described_class.create_issue_from_problem_statement(project, user, problem_statement, nil)
      end

      it 'creates an issue without base commit information' do
        expect(::Issues::CreateService).to receive(:new).with(
          container: project,
          current_user: user,
          params: hash_including(description: exclude('To reproduce this issue'))
        ).and_return(instance_double(::Issues::CreateService, execute: service_response))

        create_issue
      end

      it 'does not create issue branches' do
        expect(described_class).not_to receive(:create_issue_branch)

        create_issue
      end
    end

    context 'when an issue with the same title already exists' do
      let(:existing_issue) { instance_double(Issue, title: 'Fix the login bug') }

      before do
        allow(issues_relation).to receive(:find_by_title).with('Fix the login bug').and_return(existing_issue)
        allow(::Issues::DestroyService).to receive(:new).and_return(instance_double(::Issues::DestroyService,
          execute: true))
      end

      it 'deletes the existing issue and creates a new one' do
        expect(::Issues::DestroyService).to receive(:new).with(container: project, current_user: user)

        result = create_issue

        expect(result).to eq(created_issue)
      end
    end

    context 'when issue creation fails' do
      let(:failed_response) { ServiceResponse.error(message: 'Invalid title') }

      before do
        allow(::Issues::CreateService).to receive(:new).and_return(instance_double(::Issues::CreateService,
          execute: failed_response))
      end

      it 'returns nil and does not create branches' do
        expect(described_class).not_to receive(:create_issue_branch)

        result = create_issue

        expect(result).to be_nil
      end
    end

    context 'when an error occurs during issue creation' do
      before do
        allow(::Issues::CreateService).to receive(:new).and_raise(StandardError, 'Database error')
      end

      it 'handles error gracefully' do
        expect { create_issue }.to output(/Error creating issue/).to_stdout
      end
    end
  end

  describe '.create_issue_branch' do
    let(:repository) { instance_double(Repository) }

    subject(:create_branch) do
      described_class.create_issue_branch(project, issue, base_commit, user)
    end

    before do
      allow(project).to receive(:repository).and_return(repository)
      allow(repository).to receive(:add_branch)
    end

    it 'creates target and source branches' do
      expect(repository).to receive(:add_branch).with(user, "issue-#{issue.iid}", base_commit)
      expect(repository).to receive(:add_branch).with(user, "fix-issue-#{issue.iid}", base_commit)

      create_branch
    end

    it 'handles other errors during branch creation' do
      allow(repository).to receive(:add_branch).and_raise(StandardError, 'Repository error')

      expect { create_branch }.to output(/Error creating branch/).to_stdout
    end

    it 'handles branch already exists error gracefully' do
      allow(repository).to receive(:add_branch).and_raise(StandardError, 'Branch already exists')

      expect { create_branch }.to output(/Branch 'issue-1' already exists/).to_stdout
    end
  end

  describe '.delete_all_issues_in_subgroup' do
    let(:subgroup) { instance_double(Group, full_path: 'test-group') }
    let(:project1) { instance_double(Project, full_path: 'test-group/project1') }
    let(:project2) { instance_double(Project, full_path: 'test-group/project2') }
    let(:issue1) { instance_double(Issue, title: 'Issue 1') }
    let(:issue2) { instance_double(Issue, title: 'Issue 2') }
    let(:issue3) { instance_double(Issue, title: 'Issue 3') }
    let(:issues_relation1) { double }
    let(:issues_relation2) { double }

    subject(:delete_issues) do
      described_class.delete_all_issues_in_subgroup(subgroup, user)
    end

    before do
      allow(subgroup).to receive(:all_projects).and_return(projects_relation)
      allow(projects_relation).to receive(:find_each).and_yield(project1).and_yield(project2)
      allow(project1).to receive(:issues).and_return(issues_relation1)
      allow(project2).to receive(:issues).and_return(issues_relation2)
      allow(issues_relation1).to receive(:find_each).and_yield(issue1).and_yield(issue2)
      allow(issues_relation2).to receive(:find_each).and_yield(issue3)
      allow(::Issues::DestroyService).to receive(:new).and_return(instance_double(::Issues::DestroyService,
        execute: true))
      allow(::Projects::MarkForDeletionService).to receive(:new).and_return(instance_double(
        ::Projects::MarkForDeletionService, execute: true))
    end

    it 'deletes all issues and projects in subgroup' do
      expect(::Issues::DestroyService).to receive(:new).at_least(3).times.and_return(instance_double(
        ::Issues::DestroyService, execute: true))
      expect(::Projects::MarkForDeletionService).to receive(:new).at_least(:twice)
        .and_return(instance_double(::Projects::MarkForDeletionService, execute: true))

      delete_issues
    end

    it 'handles project deletion failure' do
      allow(::Projects::MarkForDeletionService).to receive(:new).and_return(instance_double(
        ::Projects::MarkForDeletionService, execute: false))

      expect { delete_issues }.to output(/Failed to delete project/).to_stdout
    end

    it 'handles issue deletion failure' do
      allow(::Issues::DestroyService).to receive(:new).and_raise(StandardError, 'Database error')

      expect { delete_issues }.to output(/Failed to delete issue/).to_stdout
    end

    it 'handles project-level deletion failure' do
      allow(::Issues::DestroyService).to receive(:new).and_return(instance_double(::Issues::DestroyService,
        execute: true))
      allow(::Projects::MarkForDeletionService).to receive(:new).and_raise(StandardError, 'Deletion error')

      expect { delete_issues }.to output(/Failed to delete project/).to_stdout
    end
  end

  describe '.delete_all_issues' do
    let(:issue1) { instance_double(Issue, title: 'Issue 1') }
    let(:issue2) { instance_double(Issue, title: 'Issue 2') }
    let(:issue3) { instance_double(Issue, title: 'Issue 3') }

    subject(:delete_issues) do
      described_class.delete_all_issues(project, user)
    end

    before do
      allow(project).to receive(:issues).and_return(issues_relation)
      allow(::Issues::DestroyService).to receive(:new).and_return(instance_double(::Issues::DestroyService,
        execute: true))
    end

    it 'deletes all issues from project' do
      allow(issues_relation).to receive(:find_each).and_yield(issue1).and_yield(issue2).and_yield(issue3)

      expect(::Issues::DestroyService).to receive(:new).at_least(3).times.and_return(instance_double(
        ::Issues::DestroyService, execute: true))

      delete_issues
    end

    it 'handles empty project' do
      allow(issues_relation).to receive(:find_each)

      expect { delete_issues }.to output(/Deleting all existing issues/).to_stdout
    end

    it 'handles issue deletion failure' do
      allow(issues_relation).to receive(:find_each).and_yield(issue1)
      allow(::Issues::DestroyService).to receive(:new).and_raise(StandardError, 'Database error')

      expect { delete_issues }.to output(/Failed to delete issue/).to_stdout
    end
  end
end
