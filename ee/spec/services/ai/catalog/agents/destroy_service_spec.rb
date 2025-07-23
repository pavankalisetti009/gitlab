# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::DestroyService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let!(:agent) { create(:ai_catalog_item, :with_version, project: project) }

  let(:params) { { agent: agent } }
  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  describe '#execute' do
    subject(:execute_service) { service.execute }

    shared_examples 'an error response' do |errors|
      it 'returns an error response' do
        result = execute_service

        expect(result).to be_error
        expect(result.errors).to match_array(Array(errors))
        expect(result.payload).to be_empty
      end

      it 'does not destroy any agents' do
        expect { execute_service }.not_to change { Ai::Catalog::Item.count }
      end

      it 'does not trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
        expect { execute_service }
          .not_to trigger_internal_events('delete_ai_catalog_item')
      end
    end

    context 'when agent is invalid' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when agent is nil' do
        let(:params) { { agent: nil } }

        it_behaves_like 'an error response', 'Agent not found'
      end

      context 'when catalog item is not an agent' do
        before do
          allow(agent).to receive(:agent?).and_return(false)
        end

        it_behaves_like 'an error response', 'Agent not found'
      end
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      it 'trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
        expect { execute_service }
         .to trigger_internal_events('delete_ai_catalog_item')
         .with(user: user, project: project, additional_properties: { label: 'agent' })
      end

      context 'when agent exists' do
        it 'destroys the agent successfully' do
          expect { execute_service }.to change { Ai::Catalog::Item.count }.by(-1)
        end

        it 'destroys agent versions' do
          expect { execute_service }.to change { Ai::Catalog::ItemVersion.count }.by(-1)
        end

        it 'returns success response' do
          result = execute_service

          expect(result.success?).to be(true)
          expect(result.payload).to be_empty
        end

        context 'when agent is already being used (has consumers)' do
          before do
            create(:ai_catalog_item_consumer, item: agent, project: project)
          end

          it 'soft deletes the agent' do
            expect { execute_service }.to change { agent.deleted_at }.from(nil)
          end

          it 'does not destroy the agent' do
            expect { execute_service }.not_to change { Ai::Catalog::Item.count }
          end

          it 'does not destroy agent versions' do
            expect { execute_service }.not_to change { Ai::Catalog::ItemVersion.count }
          end

          it 'returns success response' do
            result = execute_service

            expect(result.success?).to be(true)
          end
        end
      end

      context 'when agent destruction fails' do
        before do
          allow(agent).to receive(:destroy).and_return(false)
          agent.errors.add(:base, 'Agent cannot be destroyed')
        end

        it_behaves_like 'an error response', 'Agent cannot be destroyed'
      end
    end

    context 'when user lacks permissions' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end
  end
end
