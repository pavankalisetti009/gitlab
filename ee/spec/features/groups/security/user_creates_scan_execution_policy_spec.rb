# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User creates scan execution policy", :js, feature_category: :security_policy_management do
  include ListboxHelpers

  let(:path_to_policy_editor) { new_group_security_policy_path(group) }
  let(:path_to_merge_request_approval_policy_editor) { "#{path_to_policy_editor}?type=scan_execution_policy" }
  let_it_be(:owner) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group, owners: owner) }
  let_it_be(:policy_management_project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      security_policy_management_project: policy_management_project,
      namespace: group
    )
  end

  let(:limit) { Gitlab::CurrentSettings.scan_execution_policies_action_limit }

  before do
    sign_in(owner)
    stub_licensed_features(security_orchestration_policies: true)
    visit(path_to_policy_editor)
    within_testid("scan_execution_policy-card") do
      click_link _('Select policy')
    end
  end

  context "when policy is invalid" do
    it "fails to create a policy without branch information for schedules" do
      fill_in _('Name'), with: 'Missing branch information'

      select_from_listbox 'Schedules:', from: 'Triggers:'
      click_button _('Configure with a merge request')

      expect(page).to have_content('Policy cannot be enabled without branch information')
      expect(page).to have_current_path(path_to_merge_request_approval_policy_editor)
    end

    it "fails to create a policy without branch information" do
      fill_in _('Name'), with: 'Scan execution policy'

      fill_in _('Select branches'), with: ''

      click_button _('Configure with a merge request')

      expect(page).to have_content('Policy cannot be enabled without branch information')
      expect(page).to have_current_path(path_to_merge_request_approval_policy_editor)
    end

    it "fails to create a policy with exceeding amount of actions and conditions" do
      fill_in _('Name'), with: 'Exceeding actions and conditions'

      limit.times do
        click_button _('Add new action')
        click_button _('Add new condition')
      end

      expect(page).to have_button _('Add new action'), disabled: true

      click_button _('Configure with a merge request')

      expect(page).to have_content("Policy exceeds the maximum of #{limit} actions")
      expect(page).to have_current_path(path_to_merge_request_approval_policy_editor)
    end
  end
end
