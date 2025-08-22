# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::UpdateService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:agent) { create(:ai_catalog_item, public: false, project: project) }
  let_it_be_with_reload(:latest_version) { create(:ai_catalog_item_version, version: '1.1.0', item: agent) }

  let(:tools) { Ai::Catalog::BuiltInTool.where(id: [1, 9]) }
  let(:params) do
    {
      agent: agent,
      name: 'New name',
      description: 'New description',
      public: true,
      tools: tools,
      release: true,
      user_prompt: 'New user prompt',
      system_prompt: 'New system prompt'
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  describe '#execute', :freeze_time do
    subject(:execute_service) { service.execute }

    shared_examples 'an error response' do |error|
      it 'returns an error response', :aggregate_failures do
        result = execute_service

        expect(result).to be_error
        expect(result.message).to match_array(Array(error))
        expect(result.payload[:item]).to eq(agent)
      end

      it 'does not update the agent' do
        expect { execute_service }.not_to change { agent.reload.attributes }
      end

      it 'does not update the latest version' do
        expect { execute_service }.not_to change { latest_version.reload.attributes }
      end

      it 'does not trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
        expect { execute_service }
          .not_to trigger_internal_events('update_ai_catalog_item')
      end
    end

    context 'when user lacks permissions' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      it 'updates the agent and its latest version', :aggregate_failures do
        execute_service

        expect(agent.reload).to have_attributes(
          name: 'New name',
          description: 'New description',
          public: true
        )

        expect(latest_version.reload).to have_attributes(
          schema_version: 1,
          version: '1.1.0',
          release_date: Time.zone.now,
          definition: {
            user_prompt: 'New user prompt',
            tools: [1, 9],
            system_prompt: 'New system prompt'
          }.stringify_keys
        )
      end

      it 'returns success response with item in payload', :aggregate_failures do
        result = execute_service

        expect(result).to be_success
        expect(result.payload[:item]).to eq(agent)
      end

      it 'trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
        expect { execute_service }
         .to trigger_internal_events('update_ai_catalog_item')
         .with(user: user, project: project, additional_properties: { label: 'agent' })
         .and increment_usage_metrics('counts.count_total_update_ai_catalog_item')
      end

      context 'when the latest version has been released' do
        before do
          latest_version.update!(release_date: 1.day.ago)
        end

        it 'creates a new released version', :aggregate_failures do
          expect { execute_service }.to change { agent.reload.versions.count }.by(1)
          expect(agent.latest_version).not_to eq(latest_version)
          expect(agent.latest_version).to have_attributes(
            schema_version: 1,
            version: '2.0.0',
            release_date: Time.zone.now,
            definition: {
              user_prompt: 'New user prompt',
              tools: [1, 9],
              system_prompt: 'New system prompt'
            }.stringify_keys
          )
        end

        it 'does not change the older version' do
          expect { execute_service }.not_to change { latest_version.reload.attributes }
        end

        context 'when the `ai_catalog_enforce_readonly_versions` flag is disabled' do
          before do
            stub_feature_flags(ai_catalog_enforce_readonly_versions: false)
          end

          it 'does not create a new version, and updates the existing version instead', :aggregate_failures do
            expect { execute_service }.not_to change { agent.reload.versions.count }
            expect(agent.latest_version).to eq(latest_version)
            expect(agent.latest_version).to have_attributes(
              schema_version: 1,
              version: '1.1.0',
              release_date: 1.day.ago,
              definition: {
                user_prompt: 'New user prompt',
                tools: [1, 9],
                system_prompt: 'New system prompt'
              }.stringify_keys
            )
          end

          context 'when the version is not being released' do
            let(:params) { super().merge(release: false) }

            it 'does not unrelease the version', :aggregate_failures do
              expect { execute_service }.not_to change { agent.reload.versions.count }
              expect(agent.latest_version).to be_released
            end
          end
        end

        context 'when the version is not being released' do
          let(:params) { super().merge(release: nil) }

          it 'creates a new unreleased version', :aggregate_failures do
            expect { execute_service }.to change { agent.reload.versions.count }.by(1)
            expect(agent.latest_version).not_to eq(latest_version)
            expect(agent.latest_version.release_date).to be_nil
          end
        end

        context 'when only agent properties are updated' do
          let(:params) { { agent: agent, name: 'New name' } }

          it 'updates the agent' do
            expect { execute_service }.to change { agent.reload.name }.to('New name')
          end

          it 'does not create a new version' do
            expect { execute_service }.not_to change { agent.reload.versions.count }
          end
        end
      end

      context 'when only agent properties are being updated' do
        let(:params) { { agent: agent, name: 'New name' } }

        it 'updates the agent' do
          expect { execute_service }.to change { agent.reload.name }.to('New name')
        end

        it 'does not update the latest version' do
          expect { execute_service }.not_to change { latest_version.reload.attributes }
        end
      end

      describe 'updating the latest version schema version' do
        before do
          allow_next_instance_of(JsonSchemaValidator) do |validator|
            allow(validator).to receive(:validate).and_return(true)
          end

          latest_version.update!(schema_version: 999)
        end

        it 'sets it to the current schema version' do
          expect { execute_service }.to change { latest_version.reload.schema_version }
            .to(Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION)
        end

        context 'when the only change to the version is that it is being released' do
          let(:params) { { agent: agent, release: true } }

          it 'releases the version' do
            expect { execute_service }.to change { latest_version.reload.released? }.to(true)
          end

          it 'does not change the current schema version' do
            expect { execute_service }.not_to change { latest_version.reload.schema_version }
          end
        end

        context 'when only the agent is being updated' do
          let(:params) { { agent: agent, name: 'New name' } }

          it 'does not change the current schema version' do
            expect { execute_service }.not_to change { latest_version.reload.schema_version }
          end
        end
      end

      context 'when updated agent is invalid' do
        let(:params) do
          {
            agent: agent,
            name: nil
          }
        end

        it_behaves_like 'an error response', "Name can't be blank"
      end

      context 'when updated latest version is invalid' do
        before do
          stub_const('Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION', nil)
        end

        it_behaves_like 'an error response', [
          "Latest version schema version can't be blank",
          'Latest version definition unable to validate definition'
        ]
      end

      context 'when agent is not an agent' do
        before do
          allow(agent).to receive(:agent?).and_return(false)
        end

        it_behaves_like 'an error response', 'Agent not found'
      end
    end
  end
end
