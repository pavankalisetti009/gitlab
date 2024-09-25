# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/trials/_lead_form.html.haml', feature_category: :subscription_management do
  include Devise::Test::ControllerHelpers

  let(:user) { build_stubbed(:user) }

  before do
    allow(view).to receive(:current_user) { user }
  end

  it 'renders lead form' do
    render 'gitlab_subscriptions/trials/lead_form'

    expect(rendered).to have_content(_('Start your Free Ultimate and GitLab Duo Enterprise Trial'))
  end

  context 'with the duo_enterprise_trials feature flag off' do
    before do
      stub_feature_flags(duo_enterprise_trials: false)
    end

    it 'renders lead for and trial only referenced Ultimate verbage' do
      render 'gitlab_subscriptions/trials/lead_form'

      expect(rendered).to have_content(_('Start your Free Ultimate Trial'))
    end
  end
end
