# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchRules::ExternalStatusChecks::CreateService, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }

  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
  let(:action_allowed) { true }
  let(:create_service) { ExternalStatusChecks::CreateService }
  let(:create_service_instance) { instance_double(update_service) }
  let(:status_check_name) { 'Test' }
  let(:params) { { name: status_check_name, external_url: 'https://external_url.text/hello.json', shared_secret: 'shared_secret' } }

  subject(:execute) { described_class.new(branch_rule, user, params).execute }

  before do
    allow(Ability)
      .to receive(:allowed?).with(user, :update_branch_rule, branch_rule)
                            .and_return(action_allowed)

    stub_licensed_features(audit_events: true)
  end

  it_behaves_like 'create external status services'

  context 'when the given branch rule is not and instance of Projects::BranchRule' do
    let(:branch_rule) { create(:protected_branch) }

    it 'is unsuccessful' do
      expect(execute.error?).to be true
    end

    it 'does not create a new rule' do
      expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
    end

    it 'responds with the expected errors' do
      expect(execute.message).to eq('Unknown branch rule type.')
    end
  end

  context 'with ::Projects::AllBranchesRule' do
    let(:branch_rule) { ::Projects::AllBranchesRule.new(project) }

    it 'responds with the expected errors' do
      expect(execute.error?).to be true
      expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
      expect(execute.message).to eq('All branch rules cannot configure external status checks')
    end
  end

  context 'with ::Projects::AllProtectedBranchesRule' do
    let(:branch_rule) { ::Projects::AllProtectedBranchesRule.new(project) }

    it 'responds with the expected errors' do
      expect(execute.error?).to be true
      expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
      expect(execute.message).to eq('All protected branch rules cannot configure external status checks')
    end
  end
end
