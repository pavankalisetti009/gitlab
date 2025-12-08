# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/projects/premium_message_during_trial/_base.html.haml', :saas, feature_category: :acquisition do
  let(:project) { build_stubbed(:project, namespace: build_stubbed(:group)) }
  let(:user) { build_stubbed(:user) }
  let(:user_can_read_billing) { true }

  before do
    allow(view).to receive(:can?).with(user, :read_billing, project.namespace).and_return(user_can_read_billing)
    view.assign(project: project)
  end

  subject(:rendered) do
    view.render 'shared/projects/premium_message_during_trial/base',
      current_user: user,
      page: 'project',
      feature_id: EE::Users::GroupCalloutsHelper::PROJECT_PREMIUM_MESSAGE_CALLOUT
  end

  it 'does not render premium message' do
    expect(view).not_to receive(:experiment)
    expect(rendered).to be_nil
  end

  context 'when on trial' do
    let(:assigned) { true }

    before do
      build_stubbed(:gitlab_subscription, :active_trial, namespace: project.namespace)
      stub_experiments(premium_message_during_trial: { variant: :candidate, assigned: assigned })
    end

    context 'when user has been previously assigned as part of the experiment' do
      it 'runs the experiment candidate experience' do
        expect(rendered).to have_selector('#js-premium-message-during-trial')
      end
    end

    context 'when user has not been previously assigned as part of the experiment' do
      let(:assigned) { false }

      it 'does not render the candidate experience' do
        expect(rendered).not_to have_selector('#js-premium-message-during-trial')
      end
    end

    context 'when not owner' do
      let(:user_can_read_billing) { false }

      it 'does not render premium message' do
        expect(rendered).not_to have_selector('#js-premium-message-during-trial')
      end
    end
  end
end
