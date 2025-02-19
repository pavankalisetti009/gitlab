# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE user opens IDE', :js, feature_category: :web_ide do
  using RSpec::Parameterized::TableSyntax
  include Features::WebIdeSpecHelpers

  let_it_be(:unsigned_commits_warning) { 'This project does not accept unsigned commits.' }

  let(:project) { create(:project, :repository) }
  let(:user) { project.first_owner }

  before do
    stub_feature_flags(vscode_web_ide: false)

    stub_licensed_features(push_rules: true)
    stub_licensed_features(reject_unsigned_commits: true)
    sign_in(user)
  end

  shared_examples 'no warning' do |directory_code_dropdown_updates|
    it 'does not show warning' do
      stub_feature_flags(directory_code_dropdown_updates: directory_code_dropdown_updates)
      ide_visit(project)

      wait_for_all_requests

      expect(page).not_to have_text(unsigned_commits_warning)
    end
  end

  shared_examples 'has warning' do |directory_code_dropdown_updates|
    it 'shows warning' do
      stub_feature_flags(directory_code_dropdown_updates: directory_code_dropdown_updates)
      ide_visit(project)

      wait_for_all_requests

      expect(page).to have_text(unsigned_commits_warning)
    end
  end

  context 'with directory_code_dropdown_updates enabled' do
    context 'no push rules' do
      it_behaves_like 'no warning', true
    end

    context 'when has reject_unsigned_commit push rule' do
      before do
        create(:push_rule, project: project, reject_unsigned_commits: true)
      end

      it_behaves_like 'has warning', true

      context 'and feature flag off' do
        before do
          stub_feature_flags(reject_unsigned_commits_by_gitlab: false)
        end

        it_behaves_like 'no warning', true
      end
    end
  end

  context 'with directory_code_dropdown_updates disabled' do
    context 'no push rules' do
      it_behaves_like 'no warning', false
    end

    context 'when has reject_unsigned_commit push rule' do
      before do
        create(:push_rule, project: project, reject_unsigned_commits: true)
      end

      it_behaves_like 'has warning', false

      context 'and feature flag off' do
        before do
          stub_feature_flags(reject_unsigned_commits_by_gitlab: false)
        end

        it_behaves_like 'no warning', false
      end
    end
  end
end
