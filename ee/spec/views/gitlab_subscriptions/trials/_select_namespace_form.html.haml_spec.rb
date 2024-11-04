# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/trials/_select_namespace_form.html.haml', feature_category: :subscription_management do
  let(:user) { build_stubbed(:user) }
  let(:eligible_namespaces) { [] }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:eligible_namespaces, eligible_namespaces)
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
end
