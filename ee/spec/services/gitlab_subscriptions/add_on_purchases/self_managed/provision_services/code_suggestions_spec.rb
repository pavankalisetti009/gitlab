# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::CodeSuggestions,
  :aggregate_failures, feature_category: :plan_provisioning do
  subject(:result) { described_class.new.execute }

  describe '#execute', :freeze_time do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }
    let_it_be(:default_organization) { create(:organization, :default) }
    let_it_be(:namespace) { nil }
    let_it_be(:subscription_name) { 'A-S00000002' }

    let!(:current_license) do
      create_current_license(
        cloud_licensing_enabled: true,
        restrictions: {
          code_suggestions_seat_count: quantity,
          subscription_name: subscription_name
        }
      )
    end

    context 'when current license has no code suggestions information' do
      let!(:current_license) { create_current_license(cloud_licensing_enabled: true) }

      it_behaves_like 'provision service expires add-on purchase'
    end

    context 'when current license has zero code suggestions seats purchased' do
      let_it_be(:quantity) { 0 }

      it_behaves_like 'provision service expires add-on purchase'
    end

    context 'when current license has code suggestions seats purchased' do
      let_it_be(:quantity) { 1 }

      it_behaves_like 'provision service creates add-on purchase'
    end
  end
end
