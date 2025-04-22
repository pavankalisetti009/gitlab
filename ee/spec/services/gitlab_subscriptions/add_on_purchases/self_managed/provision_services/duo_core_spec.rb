# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::DuoCore,
  feature_category: :'add-on_provisioning' do
  describe '#execute' do
    subject(:provision_service) { described_class.new }

    let_it_be(:add_on_duo_core) { create(:gitlab_subscription_add_on, :duo_core) }
    let_it_be(:add_on_duo_enterprise) { create(:gitlab_subscription_add_on, :duo_enterprise) }

    let_it_be(:organization) { create(:organization) }
    let_it_be(:started_at) { Date.current }

    let(:quantity) { 1 }
    let(:trial) { false }
    let(:add_ons) { [] }

    before do
      create_current_license(
        cloud_licensing_enabled: true,
        restrictions: {
          add_on_products: add_on_products(add_ons: add_ons, started_at: started_at, quantity: quantity),
          subscription_name: 'A-S00000001'
        }
      )
    end

    describe 'delegations' do
      subject { provision_service }

      it_behaves_like 'delegates add_on params to license_add_on'
    end

    context 'without Duo Core' do
      let(:add_ons) { [] }

      it 'does not create a Duo Core add-on purchase' do
        expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }
      end
    end

    context 'with Duo Core' do
      let(:add_ons) { %i[duo_core] }

      it 'creates a new Duo Core add-on purchase' do
        expect do
          provision_service.execute
        end.to change { GitlabSubscriptions::AddOnPurchase.count }.from(0).to(1)

        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_duo_core.id,
          quantity: quantity,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: '123456789',
          trial: trial
        )
      end
    end

    context 'with existing Duo Core and seat count increase' do
      let(:add_ons) { %i[duo_core] }
      let(:quantity) { 2 }

      before do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_core,
          quantity: 1,
          namespace: nil
        )
      end

      it 'updates quantity of existing add-on purchase' do
        expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_duo_core.id,
          quantity: quantity,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: '123456789',
          trial: trial
        )
      end
    end

    context 'with existing Duo Core and additional purchase of Duo Enterprise' do
      let(:add_ons) { %i[duo_core duo_enterprise] }

      before do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_core,
          quantity: quantity,
          namespace: nil
        )
      end

      it 'does not affect duo core provision' do
        expect { provision_service.execute }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_duo_core.id,
          quantity: quantity,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: '123456789',
          trial: trial
        )
      end
    end

    context 'with an existing expired Duo Core' do
      let(:add_ons) { %i[duo_core] }

      let!(:existing_add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_core,
          quantity: quantity,
          started_at: 2.years.ago,
          expires_on: 1.year.ago,
          namespace: nil
        )
      end

      it 'updates existing add-on purchase' do
        expect do
          provision_service.execute
        end.not_to change { GitlabSubscriptions::AddOnPurchase.count }

        expect(existing_add_on_purchase.reload.started_at).to eq(started_at)
        expect(existing_add_on_purchase.expires_on).to eq(started_at + 1.year)
      end
    end
  end

  private

  def add_on_products(add_ons:, started_at:, quantity:)
    add_ons.index_with({}) do
      [
        {
          "quantity" => quantity,
          "started_on" => started_at.to_s,
          "expires_on" => (started_at + 1.year).to_s,
          "purchase_xid" => "123456789",
          "trial" => trial
        }
      ]
    end
  end
end
