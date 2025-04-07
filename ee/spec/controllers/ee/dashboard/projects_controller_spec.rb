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
end
