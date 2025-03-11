# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dashboard::ProjectsController, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }

  describe '#index' do
    render_views

    before do
      sign_in(user)
    end

    it 'pushes licensed feature' do
      get :index

      expect(response.body).to have_pushed_licensed_features(adjournedDeletionForProjectsAndGroups: false)
    end
  end

  describe '#removed' do
    render_views
    subject { get :removed, format: :json }

    before do
      sign_in(user)

      allow(Kaminari.config).to receive(:default_per_page).and_return(2)
    end

    shared_examples 'returns not found' do
      it do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when licensed' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      it 'redirects /removed to /inactive' do
        subject

        expect(response).to redirect_to(inactive_dashboard_projects_path)
      end
    end

    context 'when not licensed' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
      end

      it_behaves_like 'returns not found'
    end
  end
end
