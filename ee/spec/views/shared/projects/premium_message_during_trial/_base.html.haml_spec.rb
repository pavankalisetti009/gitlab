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
    before do
      build_stubbed(:gitlab_subscription, :active_trial, namespace: project.namespace)
    end

    it 'runs the experiment' do
      expect(view)
        .to receive(:experiment)
        .with(:premium_message_during_trial, namespace: project.namespace, only_assigned: true)

      rendered
    end

    context 'when not owner' do
      let(:user_can_read_billing) { false }

      it 'does not render premium message' do
        expect(view).not_to receive(:experiment)
        expect(rendered).to be_nil
      end
    end
  end
end
