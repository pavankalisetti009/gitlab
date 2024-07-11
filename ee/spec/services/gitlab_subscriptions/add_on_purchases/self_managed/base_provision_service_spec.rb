# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::BaseProvisionService,
  :aggregate_failures, feature_category: :plan_provisioning do
  describe '#execute' do
    it { expect { described_class.new.execute }.to raise_error described_class::MethodNotImplementedError }

    context 'with child class insufficient implemented' do
      let!(:current_license) { create_current_license(cloud_licensing_enabled: true) }

      let(:provision_dummy_add_on_service_class) do
        Class.new(described_class) do
          def name
            # One of the enums for name of GitlabSubscriptions::AddOn
            :code_suggestions
          end
        end
      end

      specify do
        expect { provision_dummy_add_on_service_class.new.execute }
          .to raise_error described_class::MethodNotImplementedError
      end
    end

    context 'with child class' do
      subject(:result) { provision_dummy_add_on_service_class.new.execute }

      let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
      let_it_be(:default_organization) { create(:organization, :default) }
      let_it_be(:namespace) { nil }
      let_it_be(:quantity) { 5 }
      let_it_be(:subscription_name) { 'A-S00000002' }

      let!(:current_license) do
        create_current_license(
          cloud_licensing_enabled: true,
          restrictions: {
            subscription_name: subscription_name
          }
        )
      end

      let(:provision_dummy_add_on_service_class) do
        quantity_from_restrictions = quantity

        Class.new(described_class) do
          define_method :quantity_from_restrictions do |_|
            quantity_from_restrictions
          end

          def name
            # One of the enums for name of GitlabSubscriptions::AddOn
            :code_suggestions
          end
        end
      end

      context 'without a current license', :without_license do
        let!(:current_license) { nil }

        it_behaves_like 'provision service expires add-on purchase'
      end

      context 'when current license is not a cloud license' do
        let!(:current_license) do
          create_current_license(
            cloud_licensing_enabled: true,
            offline_cloud_licensing_enabled: true
          )
        end

        it_behaves_like 'provision service expires add-on purchase'
      end

      context 'when current license does not contain a code suggestions add-on purchase' do
        let_it_be(:quantity) { 0 }

        it_behaves_like 'provision service expires add-on purchase'
      end

      context 'when add-on record does not exist' do
        before do
          GitlabSubscriptions::AddOn.destroy_all # rubocop: disable Cop/DestroyAll -- clean-up
        end

        it 'creates the add-on record' do
          expect { result }.to change { GitlabSubscriptions::AddOn.count }.by(1)
        end
      end

      context 'when add-on purchase exists' do
        let(:expiration_date) { Date.current + 3.months }
        let!(:existing_add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            namespace: namespace,
            add_on: add_on,
            expires_on: expiration_date
          )
        end

        context 'when the update fails' do
          it_behaves_like 'provision service handles error', GitlabSubscriptions::AddOnPurchases::UpdateService
        end

        context 'when existing add-on purchase is expired' do
          let(:expiration_date) { Date.current - 3.months }

          it_behaves_like 'provision service updates the existing add-on purchase'
        end

        it_behaves_like 'provision service updates the existing add-on purchase'
      end

      context 'when the creation fails' do
        it_behaves_like 'provision service handles error', GitlabSubscriptions::AddOnPurchases::CreateService
      end

      context 'when the license has no block_changes_at set' do
        let!(:current_license) do
          create_current_license(
            block_changes_at: nil,
            cloud_licensing_enabled: true,
            restrictions: {
              code_suggestions_seat_count: quantity,
              subscription_name: subscription_name
            }
          )
        end

        it 'uses expires_at from license' do
          expect(GitlabSubscriptions::AddOnPurchases::CreateService).to receive(:new).with(
            namespace,
            add_on,
            {
              add_on_purchase: nil,
              quantity: quantity,
              expires_on: current_license.expires_at,
              purchase_xid: subscription_name
            }
          ).and_call_original

          expect(result[:add_on_purchase]).to have_attributes(
            expires_on: current_license.expires_at
          )
        end
      end

      it_behaves_like 'provision service creates add-on purchase'
    end
  end
end
