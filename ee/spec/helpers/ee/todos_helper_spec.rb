# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::TodosHelper do
  include Devise::Test::ControllerHelpers

  let_it_be(:user) { create(:user) }

  describe '#todo_types_options' do
    it 'includes options for an epic todo' do
      expect(helper.todo_types_options).to include(
        { id: 'Epic', text: 'Epic' }
      )
    end
  end

  describe '#todo_target_path' do
    context 'when target is vulnerability' do
      let(:vulnerability) { create(:vulnerability) }
      let(:todo) { create(:todo, target: vulnerability, project: vulnerability.project) }

      subject(:todo_target_path) { helper.todo_target_path(todo) }

      it { is_expected.to eq("/#{todo.project.full_path}/-/security/vulnerabilities/#{todo.target.id}") }
    end
  end

  describe '#show_todo_state?' do
    let(:closed_epic) { create(:epic, state: 'closed') }
    let(:todo) { create(:todo, target: closed_epic) }

    it 'returns true for a closed epic' do
      expect(helper.show_todo_state?(todo)).to eq(true)
    end
  end

  describe '#todo_groups_requiring_saml_reauth' do
    let_it_be(:restricted_group) do
      create(:group, saml_provider: create(:saml_provider, enabled: true, enforced_sso: true))
    end

    let_it_be(:restricted_group2) do
      create(:group, saml_provider: create(:saml_provider, enabled: true, enforced_sso: true))
    end

    let_it_be(:restricted_subgroup) { create(:group, parent: restricted_group) }
    let_it_be(:unrestricted_group) { create(:group) }

    let_it_be(:epic_todo) { create(:todo, group: restricted_group, target: create(:epic, group: restricted_subgroup)) }

    let_it_be(:restricted_project) { create(:project, namespace: restricted_group2) }

    let_it_be(:issue_todo) do
      create(:todo, project: restricted_project, target: create(:issue, project: restricted_project))
    end

    let_it_be(:issue_todo2) do
      create(:todo, project: restricted_project, target: create(:issue, project: restricted_project))
    end

    let_it_be(:unrestricted_project) { create(:project, namespace: unrestricted_group) }

    let_it_be(:mr_todo) do
      create(:todo, project: unrestricted_project, target: create(:merge_request, source_project: unrestricted_project))
    end

    let_it_be(:user_namespace) { create(:namespace) }
    let_it_be(:user_project) { create(:project, namespace: user_namespace) }
    let_it_be(:user_namespace_issue_todo) do
      create(:todo, project: user_project, target: create(:issue, project: user_project))
    end

    let_it_be(:todos) { [epic_todo, issue_todo, issue_todo2, mr_todo, user_namespace_issue_todo] }

    let(:session) { {} }

    before do
      stub_licensed_features(group_saml: true)
    end

    around do |example|
      Gitlab::Session.with_session(session) do
        example.run
      end
    end

    it 'returns root groups for todos with targets in SSO enforced groups' do
      expect(helper.todo_groups_requiring_saml_reauth(todos)).to match_array([restricted_group, restricted_group2])
    end

    it 'sends a unique list of groups to the SSO enforcer' do
      expect(::Gitlab::Auth::GroupSaml::SsoEnforcer)
        .to receive(:access_restricted_groups).with([restricted_group, restricted_group2, unrestricted_group], any_args)

      helper.todo_groups_requiring_saml_reauth(todos)
    end

    context 'with todos that have no group relation' do
      let_it_be(:ssh_key_todo) do
        create(:todo, project: nil, group: nil, target: create(:key, user: user), user: user)
      end

      it 'ignores todos with no group relation' do
        expect(helper.todo_groups_requiring_saml_reauth([ssh_key_todo, issue_todo])).to eq([issue_todo.project.group])
      end
    end
  end

  describe '#todo_target_path_anchor' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:author) { create(:user) }

    describe 'with a mentioned todo' do
      let_it_be(:todo) do
        create(:todo,
          :mentioned,
          user: user,
          project: project,
          target: merge_request,
          author: author)
      end

      it { expect(helper.todo_target_path_anchor(todo)).to eq(nil) }
    end
  end

  describe '.todo_groups_requiring_saml_reauth', feature_category: :system_access do
    subject(:todo_groups_requiring_saml_reauth) { helper.todo_groups_requiring_saml_reauth([issue_todo, group_todo]) }

    let_it_be(:current_user) { create(:user) }

    let_it_be(:group1) { create(:group) }
    let_it_be(:project) { create(:project, group: group1) }
    let_it_be(:issue) { create(:issue, title: 'Issue 1') }
    let_it_be(:issue_todo) do
      create(:todo, target: issue, project: project)
    end

    let_it_be(:group2) { create(:group) }
    let_it_be(:group_todo) do
      create(:todo, target: group2, group: group2, project: nil, user: current_user)
    end

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
    end

    context 'when access is not restricted' do
      it 'returns an empty array' do
        expect(todo_groups_requiring_saml_reauth).to match_array([])
      end
    end

    context 'when access is restricted' do
      before do
        allow(::Gitlab::Auth::GroupSaml::SsoEnforcer).to receive(:access_restricted_groups).and_return([group1, group2])
      end

      it 'returns the todo groups' do
        expect(todo_groups_requiring_saml_reauth).to match_array([group1, group2])
      end
    end
  end
end
