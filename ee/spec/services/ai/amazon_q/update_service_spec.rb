# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::UpdateService, feature_category: :ai_agents do
  describe '#execute' do
    let_it_be(:user) { create(:admin) }
    let_it_be_with_reload(:service_account) { create(:service_account) }
    let_it_be(:integration) { create(:amazon_q_integration) }

    let_it_be(:project_integration) do
      create(:amazon_q_integration, instance: false, project: create(:project), inherit_from_id: integration.id)
    end

    let_it_be(:group_integration) do
      create(:amazon_q_integration, instance: false, group: create(:group), inherit_from_id: integration.id)
    end

    let(:params) { { availability: 'default_on', auto_review_enabled: true } }
    let(:status) { 200 }
    let(:body) { 'success' }

    subject(:instance) { described_class.new(user, params) }

    before do
      stub_licensed_features(amazon_q: true)
      Ai::Setting.instance.update!(amazon_q_service_account_user_id: service_account.id)
      ::Gitlab::CurrentSettings.current_application_settings.update!(duo_availability: 'default_off')
    end

    context 'with missing availability param' do
      let(:params) { {} }

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Missing availability parameter'
        )
      end
    end

    context 'with invalid availability param' do
      let(:params) { { availability: 'z' } }

      it 'does not change duo_availability' do
        expect { instance.execute }
          .not_to change { ::Gitlab::CurrentSettings.current_application_settings.duo_availability }
      end

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: "availability must be one of: default_on, default_off, never_on"
        )
      end
    end

    context 'when the application settings update fails' do
      before do
        allow(::Gitlab::CurrentSettings).to receive_message_chain(:current_application_settings, :update)
          .and_return(false)
        allow(::Gitlab::CurrentSettings).to receive_message_chain(
          :current_application_settings, :errors, :full_messages, :to_sentence
        ).and_return('Invalid value')
      end

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Invalid value'
        )
      end
    end

    it 'updates application settings' do
      expect { instance.execute }
        .to change {
          ::Gitlab::CurrentSettings.current_application_settings.duo_availability
        }.from(:default_off).to(:default_on)
    end

    it 'updates integration settings', :sidekiq_inline do
      expect { instance.execute }
        .to change {
          integration.reload.values_at(
            :availability, :auto_review_enabled, :merge_requests_events, :pipeline_events
          )
        }.from(['default_on', false, false, false]).to(['default_on', true, true, true])
        .and change {
          project_integration.reload.values_at(
            :availability, :auto_review_enabled, :merge_requests_events, :pipeline_events
          )
        }.from(['default_on', false, false, false]).to(['default_on', true, true, true])
        .and change {
          group_integration.reload.values_at(
            :availability, :auto_review_enabled, :merge_requests_events, :pipeline_events
          )
        }.from(['default_on', false, false, false]).to(['default_on', true, true, true])
    end

    it 'creates an audit event' do
      expect { instance.execute }.to change { AuditEvent.count }.by(1)
      expect(AuditEvent.last.details).to include(
        event_name: 'q_onbarding_updated',
        custom_message: 'Changed availability to default_on'
      )
    end

    context 'when setting availability to never_on' do
      let(:params) { { availability: 'never_on' } }

      it 'blocks service account' do
        expect { instance.execute }.to change { service_account.reload.blocked? }.from(false).to(true)
      end
    end

    context 'when service account blocked' do
      it 'unblocks service account' do
        ::Users::BlockService.new(user).execute(service_account)

        expect { instance.execute }.to change { service_account.reload.blocked? }.from(true).to(false)
      end
    end

    it 'returns ServiceResponse.success' do
      result = instance.execute

      expect(result).to be_a(ServiceResponse)
      expect(result.success?).to be(true)
    end
  end
end
