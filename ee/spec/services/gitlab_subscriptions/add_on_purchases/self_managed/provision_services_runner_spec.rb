# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServicesRunner,
  :aggregate_failures, feature_category: :'add-on_provisioning' do
  describe '#execute' do
    subject(:runner) { described_class.new }

    let_it_be(:add_on_duo_pro) { create(:gitlab_subscription_add_on, :code_suggestions) }
    let_it_be(:add_on_duo_enterprise) { create(:gitlab_subscription_add_on, :duo_enterprise) }

    let_it_be(:default_organization) { create(:organization, :default) }
    let_it_be(:subscription_name) { 'A-S00000001' }

    let(:restrictions) { { subscription_name: subscription_name } }
    let(:quantity_duo_pro) { 0 }
    let(:quantity_duo_enterprise) { 0 }

    let!(:current_license) do
      create_current_license(
        cloud_licensing_enabled: true,
        restrictions: {
          code_suggestions_seat_count: quantity_duo_pro,
          duo_enterprise: {
            quantity: quantity_duo_enterprise
          },
          subscription_name: subscription_name
        }
      )
    end

    it 'executes all the registered provision services' do
      described_class::SERVICES.each do |service_class|
        expect_next_instance_of(service_class) do |service|
          expect(service).to receive(:execute).once.and_call_original
        end
      end

      runner.execute
    end

    context 'with Duo Pro' do
      let(:quantity_duo_pro) { 1 }

      it 'creates a new Duo Pro add-on purchase' do
        expect { runner.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(GitlabSubscriptions::AddOnPurchase.pluck(:subscription_add_on_id))
          .to match_array(add_on_duo_pro.id)
      end
    end

    context 'with Duo Enterprise' do
      let(:quantity_duo_enterprise) { 1 }

      it 'creates a new Duo Enterprise add-on purchase' do
        expect { runner.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(GitlabSubscriptions::AddOnPurchase.pluck(:subscription_add_on_id))
          .to match_array(add_on_duo_enterprise.id)
      end
    end
  end
end
