# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/_workspaces_agent_availability', feature_category: :workspaces do
  let_it_be(:user) { build_stubbed(:admin) }
  let_it_be(:app_settings) { build(:application_setting) }

  # We use `view.render`, because just `render` throws a "no implicit conversion of nil into String" exception
  # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/53093#note_499060593
  subject(:rendered) { view.render('admin/application_settings/workspaces/agent_availability') }

  before do
    assign(:application_setting, app_settings)
    allow(view).to receive(:current_user).and_return(user)
  end

  [true, false].each do |license_enabled|
    [true, false].each do |flag_enabled|
      context "when license is #{license_enabled ? 'enabled' : 'disabled'} " \
        "and flag is #{flag_enabled ? 'on' : 'off'}" do
        before do
          stub_licensed_features(remote_development: license_enabled)
          stub_feature_flags(workspaces_agents_availability_admin: flag_enabled)
        end

        it "#{license_enabled && flag_enabled ? 'renders' : 'does not render'} settings" do
          if license_enabled && flag_enabled
            expect(rendered).to have_selector('#js-workspaces-agent-availability-settings')
          else
            expect(rendered).to be_nil
          end
        end
      end
    end
  end
end
