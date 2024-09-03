# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::Base,
  feature_category: :plan_provisioning do
  describe '#execute' do
    let_it_be(:subscription_name) { 'A-S00000001' }

    let!(:current_license) do
      create_current_license(
        cloud_licensing_enabled: true,
        restrictions: {
          subscription_name: subscription_name
        }
      )
    end

    context 'without quantity implemented' do
      subject(:klass) { described_class }

      let!(:current_license) { create_current_license(cloud_licensing_enabled: true) }

      it_behaves_like 'raise error for not implemented missing'
    end

    context 'without add_on_purchase implemented' do
      subject(:klass) { provision_service_class }

      let(:provision_service_class) do
        Class.new(described_class) do
          define_method :quantity do
            0
          end
        end
      end

      it_behaves_like 'raise error for not implemented missing'
    end

    context 'without add_on implemented' do
      subject(:klass) { provision_service_class }

      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }
      let_it_be(:current_license) { create_current_license(cloud_licensing_enabled: true) }

      let(:provision_service_class) do
        current_add_on_purchase = add_on_purchase

        Class.new(described_class) do
          define_method :quantity do
            1
          end

          define_method :add_on_purchase do
            current_add_on_purchase
          end
        end
      end

      it_behaves_like 'raise error for not implemented missing'
    end

    context 'without starts_at implemented' do
      subject(:klass) { provision_service_class }

      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

      let(:provision_service_class) do
        current_add_on_purchase = add_on_purchase

        Class.new(described_class) do
          define_method :quantity do
            1
          end

          define_method :add_on do
            current_add_on_purchase.add_on
          end

          define_method :add_on_purchase do
            current_add_on_purchase
          end

          define_method :expires_on do
            starts_at + 1.year
          end

          define_method :purchase_xid do
            'C-12345678'
          end

          define_method :trial? do
            false
          end
        end
      end

      it_behaves_like 'raise error for not implemented missing'
    end

    context 'without expires_on implemented' do
      subject(:klass) { provision_service_class }

      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

      let(:provision_service_class) do
        current_add_on_purchase = add_on_purchase

        Class.new(described_class) do
          define_method :quantity do
            1
          end

          define_method :add_on do
            current_add_on_purchase.add_on
          end

          define_method :add_on_purchase do
            current_add_on_purchase
          end

          define_method :starts_at do
            Date.current
          end

          define_method :purchase_xid do
            'C-12345678'
          end

          define_method :trial? do
            false
          end
        end
      end

      it_behaves_like 'raise error for not implemented missing'
    end

    context 'without purchase_xid implemented' do
      subject(:klass) { provision_service_class }

      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

      let(:provision_service_class) do
        current_add_on_purchase = add_on_purchase

        Class.new(described_class) do
          define_method :quantity do
            1
          end

          define_method :add_on do
            current_add_on_purchase.add_on
          end

          define_method :add_on_purchase do
            current_add_on_purchase
          end

          define_method :starts_at do
            Date.current
          end

          define_method :expires_on do
            starts_at + 1.year
          end

          define_method :trial? do
            false
          end
        end
      end

      it_behaves_like 'raise error for not implemented missing'
    end

    context 'without trial? implemented' do
      subject(:klass) { provision_service_class }

      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

      let(:provision_service_class) do
        current_add_on_purchase = add_on_purchase

        Class.new(described_class) do
          define_method :quantity do
            1
          end

          define_method :add_on do
            current_add_on_purchase.add_on
          end

          define_method :add_on_purchase do
            current_add_on_purchase
          end

          define_method :starts_at do
            Date.current
          end

          define_method :expires_on do
            starts_at + 1.year
          end

          define_method :purchase_xid do
            'C-12345678'
          end
        end
      end

      it_behaves_like 'raise error for not implemented missing'
    end

    context 'with implemented class', :aggregate_failures do
      subject(:result) { provision_services_base_class.new.execute }

      let_it_be(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }
      let_it_be(:add_on_purchase) { nil }
      let_it_be(:default_organization) { create(:organization, :default) }
      let_it_be(:namespace) { nil }
      let_it_be(:quantity) { 1 }
      let_it_be(:starts_at) { Date.current }
      let_it_be(:purchase_xid) { 'C-12345678' }
      let_it_be(:trial) { false }

      let(:provision_services_base_class) do
        current_add_on = add_on
        current_add_on_purchase = add_on_purchase
        current_quantity = quantity
        current_starts_at = starts_at
        current_purchase_xid = purchase_xid
        current_trial = trial

        Class.new(described_class) do
          define_method :add_on_purchase do
            current_add_on_purchase
          end

          define_method :add_on do
            current_add_on
          end

          define_method :quantity do
            current_quantity
          end

          define_method :starts_at do
            current_starts_at
          end

          define_method :expires_on do
            current_starts_at + 1.year
          end

          define_method :purchase_xid do
            current_purchase_xid
          end

          define_method :trial? do
            current_trial
          end
        end
      end

      context 'without a current license', :without_license do
        let!(:current_license) { nil }

        it_behaves_like 'provision service expires add-on purchase'
      end

      context 'when current license is not an online cloud license' do
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

      context 'when add-on purchase exists' do
        let(:expires_on) { Date.current + 3.months }
        let!(:add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            namespace: namespace,
            add_on: add_on,
            started_at: current_license.starts_at,
            expires_on: expires_on,
            purchase_xid: 'A-S00000001'
          )
        end

        context 'when the update fails' do
          it_behaves_like 'provision service handles error', GitlabSubscriptions::AddOnPurchases::UpdateService
        end

        context 'when existing add-on purchase is expired' do
          let(:expires_on) { Date.current - 3.months }

          it_behaves_like 'provision service updates the existing add-on purchase'
        end

        it_behaves_like 'provision service updates the existing add-on purchase'
      end

      context 'when the creation fails' do
        it_behaves_like 'provision service handles error', GitlabSubscriptions::AddOnPurchases::CreateService
      end

      it 'creates a new add-on purchase' do
        expect(GitlabSubscriptions::AddOnPurchases::CreateService).to receive(:new).with(
          namespace,
          add_on,
          {
            add_on_purchase: nil,
            quantity: quantity,
            started_on: starts_at,
            expires_on: starts_at + 1.year,
            purchase_xid: purchase_xid,
            trial: false
          }
        ).and_call_original

        expect { result }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(result[:status]).to eq(:success)
        expect(result[:add_on_purchase].add_on.name).to eq('code_suggestions')
        expect(result[:add_on_purchase]).to have_attributes(
          started_at: starts_at,
          expires_on: starts_at + 1.year,
          quantity: quantity,
          purchase_xid: purchase_xid,
          trial: false
        )
      end
    end
  end
end
