# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::Duo,
  :aggregate_failures, feature_category: :'add-on_provisioning' do
  describe '#execute' do
    subject(:provision_service) { described_class.new }

    let_it_be(:add_on_duo_pro) { create(:gitlab_subscription_add_on, :code_suggestions) }
    let_it_be(:add_on_duo_enterprise) { create(:gitlab_subscription_add_on, :duo_enterprise) }

    let_it_be(:default_organization) { create(:organization, :default) }

    let(:quantity_duo_pro) { 0 }
    let(:quantity_duo_enterprise) { 0 }
    let(:namespace) { nil }

    let!(:current_license) do
      add_on_products = {}
      add_on_products[:duo_pro] = [{ quantity: quantity_duo_pro }] if quantity_duo_pro > 0
      add_on_products[:duo_enterprise] = [{ quantity: quantity_duo_enterprise }] if quantity_duo_enterprise > 0

      create_current_license(
        cloud_licensing_enabled: true,
        restrictions: {
          add_on_products: add_on_products,
          subscription_name: 'A-S00000001'
        }
      )
    end

    context 'with Duo Pro' do
      let(:quantity_duo_pro) { 1 }

      it 'creates a new Duo Pro add-on purchase' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(GitlabSubscriptions::AddOnPurchase.pluck(:subscription_add_on_id))
          .to match_array(add_on_duo_pro.id)
      end
    end

    context 'with existing Duo Pro and seat count increase' do
      let!(:add_on_purchase_duo_pro) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_pro,
          quantity: 1,
          namespace: namespace
        )
      end

      let(:quantity_duo_pro) { 2 }

      it 'updates quantity of existing add-on purchase' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(0)

        expect(GitlabSubscriptions::AddOnPurchase.pluck(:quantity)).to match_array(2)
      end
    end

    context 'with existing Duo Pro and additional purchase of Duo Enterprise' do
      let!(:add_on_purchase_duo_pro) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_pro,
          quantity: quantity_duo_pro,
          namespace: namespace
        )
      end

      let(:quantity_duo_enterprise) { 1 }
      let(:quantity_duo_pro) { 1 }

      it 'upgrade to Duo Enterprise' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(0)

        expect(GitlabSubscriptions::AddOnPurchase.pluck(:subscription_add_on_id))
          .to match_array(add_on_duo_enterprise.id)
      end
    end

    context 'with Duo Enterprise' do
      let(:quantity_duo_enterprise) { 1 }

      it 'creates a new Duo Enterprise add-on purchase' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(GitlabSubscriptions::AddOnPurchase.pluck(:subscription_add_on_id))
          .to match_array(add_on_duo_enterprise.id)
      end
    end

    context 'with existing Duo Enterprise and seat count increase' do
      let!(:add_on_purchase_duo_enterprise) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_enterprise,
          quantity: 1,
          namespace: namespace
        )
      end

      let(:quantity_duo_enterprise) { 2 }

      it 'updates quantity of existing add-on purchase' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(0)

        expect(GitlabSubscriptions::AddOnPurchase.pluck(:quantity)).to match_array(2)
      end
    end

    context 'with existing Duo Enterprise and downgrade to Duo Pro' do
      let!(:add_on_purchase_duo_enterprise) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_enterprise,
          quantity: 1,
          namespace: namespace
        )
      end

      let(:quantity_duo_enterprise) { 0 }
      let(:quantity_duo_pro) { 1 }

      it 'downgrades to Duo Pro' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(0)

        expect(GitlabSubscriptions::AddOnPurchase.pluck(:subscription_add_on_id))
          .to match_array(add_on_duo_pro.id)
      end
    end
  end
end
