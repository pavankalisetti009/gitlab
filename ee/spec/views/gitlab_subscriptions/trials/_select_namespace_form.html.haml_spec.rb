# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/trials/_select_namespace_form.html.haml', feature_category: :subscription_management do
  let(:user) { build_stubbed(:user) }
  let(:duo_enterprise_trials_enabled) { true }
  let(:eligible_namespaces) { [] }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:eligible_namespaces, eligible_namespaces)
    stub_feature_flags(duo_enterprise_trials: duo_enterprise_trials_enabled)
  end

  subject { render && rendered }

  it { is_expected.to have_content(s_('Trial|Apply your trial to a new group')) }

  context 'when there are eligible existing groups' do
    let(:eligible_namespaces) { [build_stubbed(:group)] }

    before do
      allow(view).to receive(:any_trial_eligible_namespaces?).and_return(true)
    end

    it { is_expected.to have_content(s_('Trial|Apply your trial to a new or existing group')) }
  end

  context 'when duo_enterprise_trials feature is disabled' do
    let(:duo_enterprise_trials_enabled) { false }

    it { is_expected.to have_content(_('Almost there')) }
  end
end
