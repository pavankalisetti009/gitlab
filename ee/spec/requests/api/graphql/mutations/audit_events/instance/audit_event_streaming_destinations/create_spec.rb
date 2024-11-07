# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an instance level  external audit event destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:owner) { create(:admin) }
  let_it_be(:config) do
    {
      "url" => 'https://gitlab.com/example/testendpoint'
    }
  end

  let(:current_user) { owner }
  let(:mutation) { graphql_mutation(:instance_audit_event_streaming_destinations_create, input) }
  let(:mutation_response) { graphql_mutation_response(:instance_audit_event_streaming_destinations_create) }

  let(:input) do
    {
      config: config,
      category: 'http',
      secretToken: 'random_secret_token'
    }
  end

  shared_examples 'creates an audit event' do
    it 'audits the creation' do
      expect { subject }
        .to change { AuditEvent.count }.by(1)
    end
  end

  shared_examples 'a mutation that does not create a destination' do
    it 'does not destroy the destination' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { AuditEvents::Instance::ExternalStreamingDestination.count }
    end

    it 'does not audit the creation' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { AuditEvent.count }
    end
  end

  context 'when feature is licensed' do
    subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is instance admin' do
      it 'creates the destination' do
        expect { mutate }
          .to change { AuditEvents::Instance::ExternalStreamingDestination.count }.by(1)

        destination = AuditEvents::Instance::ExternalStreamingDestination.last
        expect(destination.config).to eq(config)
        expect(destination.name).not_to be_empty
        expect(destination.category).to eq('http')
        expect(destination.secret_token).to eq('random_secret_token')
      end

      it_behaves_like 'creates an audit event'

      context 'for category' do
        context 'when category is invalid' do
          let(:input) do
            {
              config: config,
              category: 'invalid',
              secretToken: 'random_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end

        context 'when category is not provided' do
          let(:input) do
            {
              config: config,
              secretToken: 'random_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end
      end

      context 'when secret_token is not provided for non http category' do
        let(:input) do
          {
            config: config,
            category: 'aws'
          }
        end

        it_behaves_like 'a mutation that does not create a destination'
      end

      context 'when secret_token is not provided for http category' do
        let(:input) do
          {
            config: config,
            category: 'http'
          }
        end

        it 'creates a destination with an auto-generated secret token' do
          expect { mutate }
          .to change { AuditEvents::Instance::ExternalStreamingDestination.count }.by(1)

          destination = AuditEvents::Instance::ExternalStreamingDestination.last

          expect(destination.secret_token).not_to be_empty
          expect(destination.secret_token).not_to eq('random_secret_token')
          expect(mutation_response['externalAuditEventDestination']['secretToken']).to eq(destination.secret_token)
        end

        it_behaves_like 'creates an audit event'
      end

      context 'for config' do
        context 'when config is invalid' do
          let(:input) do
            {
              config: "string_value",
              category: 'http',
              secretToken: 'random_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end

        context 'when config is not provided' do
          let(:input) do
            {
              category: 'http',
              secretToken: 'random_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end
      end
    end

    context 'when current user is not instance admin' do
      let(:current_user) { create(:user) }

      it_behaves_like 'a mutation that does not create a destination'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'

    it 'does not create the destination' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { AuditEvents::Instance::ExternalStreamingDestination.count }
    end
  end
end
