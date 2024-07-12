# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::DuoEnterprise,
  :aggregate_failures, feature_category: :"add-on_provisioning" do
  subject(:result) { described_class.new.execute }

  describe '#execute', :freeze_time do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let_it_be(:default_organization) { create(:organization, :default) }
    let_it_be(:namespace) { nil }
    let_it_be(:subscription_name) { 'A-S00000002' }

    let!(:current_license) do
      create_current_license(
        cloud_licensing_enabled: true,
        restrictions: {
          duo_enterprise: {
            quantity: quantity
          },
          subscription_name: subscription_name
        }
      )
    end

    context 'when current license has no Duo Enterprise information' do
      let!(:current_license) { create_current_license(cloud_licensing_enabled: true) }

      it_behaves_like 'provision service expires add-on purchase'
    end

    context 'when current license has zero Duo Enterprise seats purchased' do
      let_it_be(:quantity) { 0 }

      it_behaves_like 'provision service expires add-on purchase'
    end

    context 'when current license has Duo Enterprise seats purchased' do
      let_it_be(:quantity) { 1 }

      it_behaves_like 'provision service creates add-on purchase'
    end
  end
end
