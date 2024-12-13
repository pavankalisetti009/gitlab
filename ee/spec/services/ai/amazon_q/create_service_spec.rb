# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::CreateService, feature_category: :ai_agents do
  describe '#execute' do
    let_it_be(:user) { create(:admin) }
    let_it_be(:service_account) { create(:service_account) }
    let_it_be(:doorkeeper_application) { create(:doorkeeper_application) }

    let(:params) { { role_arn: 'a', availability: 'default_off' } }
    let(:status) { 200 }
    let(:body) { 'success' }

    before do
      allow_next_instance_of(::Users::ServiceAccounts::CreateService) do |instance|
        allow(instance).to receive(:execute).and_return({ status: :success, payload: service_account })
      end

      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/oauth/application")
        .and_return(status: status, body: body)
    end

    subject(:instance) { described_class.new(user, params) }

    context 'with missing role_arn param' do
      let(:params) { { availability: 'b' } }

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Missing role_arn parameter'
        )
      end
    end

    context 'with missing availability param' do
      let(:params) { { role_arn: 'a' } }

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Missing availability parameter'
        )
      end
    end

    context 'with invalid availability param' do
      let(:params) { { role_arn: 'a', availability: 'z' } }

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

    context 'when setting availability to never_on' do
      let(:params) { { role_arn: 'a', availability: 'never_on' } }

      it 'blocks service account' do
        expect { instance.execute }.to change { service_account.blocked? }.from(false).to(true)
      end
    end

    it 'updates application settings' do
      expect { instance.execute }
        .to change { Ai::Setting.instance.amazon_q_role_arn }.from(nil).to('a')
        .and change {
          ::Gitlab::CurrentSettings.current_application_settings.duo_availability
        }.from(:default_on).to(:default_off)
    end

    it 'creates an audit event' do
      expect { instance.execute }.to change { AuditEvent.count }.by(1)
      expect(AuditEvent.last.details).to include(
        event_name: 'q_onbarding_updated',
        custom_message: "Changed availability to default_off, " \
          "amazon_q_role_arn to a, " \
          "amazon_q_service_account_user_id to #{service_account.id}, " \
          "amazon_q_oauth_application_id to #{Doorkeeper::Application.last.id}, " \
          "amazon_q_ready to true"
      )
    end

    it 'returns ServiceResponse.success' do
      result = instance.execute

      expect(result).to be_a(ServiceResponse)
      expect(result.success?).to be(true)
    end

    context 'when q service account does not already exist' do
      it 'creates q service account and stores the user id in application settings' do
        expect { instance.execute }
          .to change { Ai::Setting.instance.amazon_q_service_account_user_id }.from(nil).to(service_account.id)
        expect(::Users::ServiceAccounts::CreateService).to have_received(:new)
      end
    end

    context 'when q service account already exists' do
      before do
        Ai::Setting.instance.update!(amazon_q_service_account_user_id: service_account.id)
      end

      it 'does not attempt to create q service account' do
        expect { instance.execute }.not_to change { Ai::Setting.instance.amazon_q_service_account_user_id }
        expect(::Users::ServiceAccounts::CreateService).not_to have_received(:new)
      end
    end

    context 'when an existing oauth application does not exist' do
      it 'creates a new oauth application' do
        expect_next_instance_of(::Gitlab::Llm::QAi::Client) do |client|
          expect(client).to receive(:perform_create_auth_application)
            .with(
              doorkeeper_application,
              doorkeeper_application.secret,
              params[:role_arn]
            ).and_call_original
        end

        expect(Doorkeeper::Application).to receive(:new).with(
          {
            name: 'Amazon Q OAuth',
            redirect_uri: Gitlab::Routing.url_helpers.root_url,
            scopes: [:api, :read_repository, :write_repository, :"user:*"],
            trusted: false,
            confidential: false
          }
        ).and_return(doorkeeper_application)

        expect { instance.execute }.to change { Ai::Setting.instance.amazon_q_oauth_application_id }
          .from(nil).to(doorkeeper_application.id)
      end

      context 'when AI client returns a 403 error' do
        let(:status) { 403 }
        let(:body) { '403 Unauthorized' }

        it 'displays a 403 error in the errors' do
          expect(instance.execute).to have_attributes(
            success?: false,
            message: 'Application could not be created by the AI Gateway: Error 403 - 403 Unauthorized'
          )
        end
      end
    end

    context 'when an oauth application exists' do
      before do
        Ai::Setting.instance.update!(amazon_q_oauth_application_id: doorkeeper_application.id)
      end

      it 'does not create a new oauth application' do
        expect(Doorkeeper::Application).not_to receive(:new)

        expect_next_instance_of(::Gitlab::Llm::QAi::Client) do |client|
          expect(client).to receive(:perform_create_auth_application)
            .with(
              doorkeeper_application,
              doorkeeper_application.secret,
              params[:role_arn]
            ).and_call_original
        end

        result = nil
        expect do
          result = instance.execute
        end.not_to change {
          Ai::Setting.instance.amazon_q_oauth_application_id
        }

        expect(result.success?).to be_truthy
      end
    end
  end
end
