# frozen_string_literal: true

require 'rake_helper'

RSpec.describe 'gitlab:duo_workflow rake tasks', :silence_stdout, feature_category: :duo_workflow do
  before do
    Rake.application.rake_require 'tasks/gitlab/duo_workflow/duo_workflow'
  end

  describe 'gitlab:duo_workflow:populate' do
    let!(:user) { create(:user) }
    let!(:project) { create(:project) }
    let!(:gitlab_test_project) do
      create(:project, path: 'gitlab-test', namespace: create(:group, path: 'gitlab-org'))
    end

    it 'creates the specified number of workflows' do
      expect { run_rake_task('gitlab:duo_workflow:populate', '5', '2') }
        .to change { Ai::DuoWorkflows::Workflow.count }.by(5)
    end

    it 'assigns the specified number of workflows to first available user when no user specified' do
      run_rake_task('gitlab:duo_workflow:populate', '10', '3')

      expect(Ai::DuoWorkflows::Workflow.count).to eq(10)
      first_user_workflows = Ai::DuoWorkflows::Workflow.where(user_id: User.first.id)
      expect(first_user_workflows.count).to eq(3)
    end

    it 'assigns workflows to specified user by ID' do
      run_rake_task('gitlab:duo_workflow:populate', '5', '2', user.id.to_s)

      expect(Ai::DuoWorkflows::Workflow.count).to eq(5)
      user_workflows = Ai::DuoWorkflows::Workflow.where(user_id: user.id)
      expect(user_workflows.count).to eq(2)
    end

    it 'assigns workflows to specified user by email' do
      run_rake_task('gitlab:duo_workflow:populate', '5', '2', user.email)

      expect(Ai::DuoWorkflows::Workflow.count).to eq(5)
      user_workflows = Ai::DuoWorkflows::Workflow.where(user_id: user.id)
      expect(user_workflows.count).to eq(2)
    end

    it 'assigns workflows to specified user by username' do
      run_rake_task('gitlab:duo_workflow:populate', '5', '2', user.username)

      expect(Ai::DuoWorkflows::Workflow.count).to eq(5)
      user_workflows = Ai::DuoWorkflows::Workflow.where(user_id: user.id)
      expect(user_workflows.count).to eq(2)
    end

    it 'assigns workflows to default project when no project specified' do
      run_rake_task('gitlab:duo_workflow:populate', '3', '1')

      workflows = Ai::DuoWorkflows::Workflow.all
      expect(workflows.count).to eq(3)
      expect(workflows.all? { |w| w.project_id == gitlab_test_project.id }).to be true
    end

    it 'assigns workflows to specified project by path' do
      run_rake_task('gitlab:duo_workflow:populate', '3', '1', '', project.full_path)

      workflows = Ai::DuoWorkflows::Workflow.all
      expect(workflows.count).to eq(3)
      expect(workflows.all? { |w| w.project_id == project.id }).to be true
    end

    it 'creates workflows with valid attributes' do
      run_rake_task('gitlab:duo_workflow:populate', '3', '1')

      workflow = Ai::DuoWorkflows::Workflow.last
      expect(workflow.goal).to be_present
      expect(workflow.status).to be_present
      expect(workflow.workflow_definition).to be_in(%w[software_development chat convert_to_gitlab_ci])
      expect(workflow.agent_privileges).to be_present
      expect(workflow.pre_approved_agent_privileges).to be_present
      expect(workflow.user).to be_present
      expect(workflow.project).to be_present
    end

    it 'uses default values when no arguments provided' do
      expect { run_rake_task('gitlab:duo_workflow:populate') }
        .to change { Ai::DuoWorkflows::Workflow.count }.by(50)

      first_user_workflows = Ai::DuoWorkflows::Workflow.where(user_id: User.first.id)
      expect(first_user_workflows.count).to eq(24)
    end

    context 'when current_user_count exceeds total count' do
      it 'exits with error' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '5', '10') }
          .to raise_error(SystemExit)
      end
    end

    context 'when specified user does not exist' do
      it 'exits with error for invalid user ID' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1', '99999') }
          .to raise_error(SystemExit)
      end

      it 'exits with error for invalid email' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1', 'nonexistent@example.com') }
          .to raise_error(SystemExit)
      end

      it 'exits with error for invalid username' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1', 'nonexistent_user') }
          .to raise_error(SystemExit)
      end
    end

    context 'when specified project does not exist' do
      it 'exits with error' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1', '', 'nonexistent/project') }
          .to raise_error(SystemExit)
      end
    end

    context 'when default project does not exist' do
      before do
        gitlab_test_project.destroy!
      end

      it 'falls back to first available project' do
        run_rake_task('gitlab:duo_workflow:populate', '3', '1')

        workflows = Ai::DuoWorkflows::Workflow.all
        expect(workflows.count).to eq(3)
        expect(workflows.all? { |w| w.project_id == Project.first.id }).to be true
      end
    end

    context 'when no projects exist' do
      before do
        Project.delete_all
      end

      it 'exits with error' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1') }
          .to raise_error(SystemExit)
      end
    end

    context 'when no users exist' do
      before do
        User.delete_all
      end

      it 'exits with error' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1') }
          .to raise_error(SystemExit)
      end
    end
  end
end
