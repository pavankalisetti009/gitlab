# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabDuoController, type: :request, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  subject(:get_page) { get group_settings_gitlab_duo_path(group) }

  before do
    stub_licensed_features(code_suggestions: true)
    add_on = create(:gitlab_subscription_add_on)
    create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: group, add_on: add_on)
    sign_in(user)
  end

  context 'when user has read_usage_quotas permission' do
    before_all do
      group.add_owner(user)
    end

    it "redirects to seat utilization page" do
      get_page

      expect(response).to redirect_to(group_settings_gitlab_duo_seat_utilization_index_path(group))
      expect(response).to have_gitlab_http_status(:moved_permanently)
    end

    context 'when in a subgroup' do
      let(:subgroup) { create(:group, :private, parent: group) }

      before do
        subgroup.add_owner(user)
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it "redirects to seat utilization page" do
        get group_settings_gitlab_duo_path(subgroup)

        expect(response).to redirect_to(group_settings_gitlab_duo_seat_utilization_index_path(subgroup))
        expect(response).to have_gitlab_http_status(:moved_permanently)
      end
    end
  end

  context 'when user does not have read_usage_quotas permission' do
    before_all do
      group.add_maintainer(user)
    end

    it "redirects to seat utilization page" do
      get_page

      expect(response).to redirect_to(group_settings_gitlab_duo_seat_utilization_index_path(group))
      expect(response).to have_gitlab_http_status(:moved_permanently)
    end
  end
end
