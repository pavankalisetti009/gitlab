# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/project', feature_category: :groups_and_projects do
  let(:user) { build_stubbed(:user) }

  before do
    assign(:project, project)
    allow(view).to receive(:current_user_mode).and_return(Gitlab::Auth::CurrentUserMode.new(user))
  end

  context 'when free plan limit alert is present' do
    let_it_be(:project) { create(:project, :in_group) }

    it 'renders the alert partial' do
      render

      expect(rendered).to render_template('projects/_free_user_cap_alert')
    end
  end

  describe '_unlimited_members_during_trial_alert' do
    let(:project) { build_stubbed(:project) }

    context 'when alert is hidden' do
      before do
        view.content_for(:hide_unlimited_members_during_trial_alert, true)
      end

      it 'does not render the alert' do
        render

        expect(rendered).not_to render_template('shared/_unlimited_members_during_trial_alert')
      end
    end

    context 'when alert is rendered' do
      it 'renders the alert' do
        render

        expect(rendered).to render_template('shared/_unlimited_members_during_trial_alert')
      end
    end
  end
end
