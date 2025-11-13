# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::AuditEventMessageService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be(:version) { agent.latest_version }

  let(:params) { {} }
  let(:service) { described_class.new(event_type, agent, params) }

  describe '#messages' do
    subject(:messages) { service.messages }

    context 'when event_type is create_ai_catalog_agent' do
      let(:event_type) { 'create_ai_catalog_agent' }

      context 'with tools' do
        before do
          version.update!(definition: { 'tools' => [1, 2], 'system_prompt' => 'Test prompt' })
        end

        it 'returns create messages with tools' do
          expect(messages).to contain_exactly(
            "Created a new private AI agent with tools: [gitlab_blob_search, ci_linter]",
            "Created new draft version #{version.version} of AI agent"
          )
        end
      end

      context 'when agent is public' do
        before do
          agent.update!(public: true)
          version.update!(definition: { 'tools' => [1, 2], 'system_prompt' => 'Test prompt' })
        end

        it 'returns create messages for public agent' do
          expect(messages).to contain_exactly(
            "Created a new public AI agent with tools: [gitlab_blob_search, ci_linter]",
            "Created new draft version #{version.version} of AI agent"
          )
        end
      end

      context 'when version is released' do
        let_it_be(:released_agent) { create(:ai_catalog_agent, project: project) }
        let(:agent) { released_agent }
        let(:version) { released_agent.latest_version }

        before do
          version.update!(definition: { 'tools' => [1, 2], 'system_prompt' => 'Test prompt' },
            release_date: Time.current)
        end

        it 'returns create messages with released version' do
          expect(messages).to contain_exactly(
            "Created a new private AI agent with tools: [gitlab_blob_search, ci_linter]",
            "Released version #{version.version} of AI agent"
          )
        end
      end

      context 'when agent has no tools' do
        before do
          version.update!(definition: { 'tools' => [], 'system_prompt' => 'Test prompt' })
        end

        it 'returns create messages with empty tools list' do
          expect(messages).to contain_exactly(
            "Created a new public AI agent with tools: []",
            "Created new draft version #{version.version} of AI agent"
          )
        end
      end
    end

    context 'when event_type is update_ai_catalog_agent' do
      let(:event_type) { 'update_ai_catalog_agent' }
      let_it_be(:update_agent) { create(:ai_catalog_agent, project: project) }

      context 'when tools are added' do
        let(:agent) { update_agent }
        let(:version) { update_agent.latest_version }
        let(:params) { { old_definition: { 'tools' => [1], 'system_prompt' => 'Old prompt' } } }

        before do
          version.update!(definition: { 'tools' => [1, 2], 'system_prompt' => 'Old prompt' })
        end

        it 'returns tool addition message' do
          expect(messages).to contain_exactly(
            "Updated AI agent: Added tools: [ci_linter]"
          )
        end
      end

      context 'when tools are removed' do
        let(:agent) { update_agent }
        let(:version) { update_agent.latest_version }
        let(:params) { { old_definition: { 'tools' => [1, 2], 'system_prompt' => 'Old prompt' } } }

        before do
          version.update!(definition: { 'tools' => [1], 'system_prompt' => 'Old prompt' })
        end

        it 'returns tool removal message' do
          expect(messages).to contain_exactly(
            "Updated AI agent: Removed tools: [ci_linter]"
          )
        end
      end

      context 'when system prompt is changed' do
        let(:agent) { update_agent }
        let(:version) { update_agent.latest_version }
        let(:params) { { old_definition: { 'tools' => [1], 'system_prompt' => 'Old prompt' } } }

        before do
          version.update!(definition: { 'tools' => [1], 'system_prompt' => 'New prompt' })
        end

        it 'returns system prompt change message' do
          expect(messages).to contain_exactly(
            "Updated AI agent: Changed system prompt"
          )
        end
      end

      context 'when multiple changes occur' do
        let(:agent) { update_agent }
        let(:version) { update_agent.latest_version }
        let(:params) { { old_definition: { 'tools' => [1], 'system_prompt' => 'Old prompt' } } }

        before do
          version.update!(definition: { 'tools' => [1, 2, 3], 'system_prompt' => 'New prompt' })
        end

        it 'returns combined update message' do
          expect(messages).to contain_exactly(
            "Updated AI agent: Added tools: [ci_linter, run_git_command], Changed system prompt"
          )
        end
      end

      context 'when visibility changes from private to public' do
        let_it_be(:private_agent) { create(:ai_catalog_agent, project: project, public: false) }
        let(:agent) { private_agent }
        let(:version) { private_agent.latest_version }

        before do
          agent.update!(public: true)
        end

        it 'returns visibility change message' do
          expect(messages).to contain_exactly('Made AI agent public')
        end
      end

      context 'when visibility changes from public to private' do
        let_it_be(:public_agent) { create(:ai_catalog_agent, project: project, public: true) }
        let(:agent) { public_agent }
        let(:version) { public_agent.latest_version }

        before do
          agent.update!(public: false)
        end

        it 'returns visibility change message' do
          expect(messages).to contain_exactly('Made AI agent private')
        end
      end

      context 'when new version is created' do
        let(:agent) { update_agent }
        let(:params) { { old_definition: { 'tools' => [1], 'system_prompt' => 'You are issue planner' } } }

        before do
          new_version = create(
            :ai_catalog_agent_version,
            item: agent,
            version: '2.0.0',
            definition: { 'tools' => [1, 2], 'system_prompt' => 'You are issue planner' }
          )
          agent.update!(latest_version: new_version)
        end

        it 'returns version creation message' do
          expect(messages).to contain_exactly(
            "Created new draft version 2.0.0 of AI agent",
            "Updated AI agent: Added tools: [ci_linter]"
          )
        end
      end

      context 'when version is released' do
        let(:agent) { update_agent }
        let(:version) { update_agent.latest_version }

        before do
          version.update!(release_date: Time.current)
        end

        it 'returns version release message' do
          expect(messages).to contain_exactly(
            "Released version #{version.version} of AI agent"
          )
        end
      end

      context 'when the agent is updated but the version definition remains unchanged' do
        let(:agent) { create(:ai_catalog_agent, project: project) }

        it 'returns default update message' do
          expect(messages).to eq(['Updated AI agent'])
        end
      end
    end

    context 'when event_type is delete_ai_catalog_agent' do
      let(:event_type) { 'delete_ai_catalog_agent' }

      it 'returns delete message' do
        expect(messages).to eq(['Deleted AI agent'])
      end
    end

    context 'when event_type is enable_ai_catalog_agent' do
      let(:event_type) { 'enable_ai_catalog_agent' }

      it 'returns enable message' do
        expect(messages).to eq(['Added AI agent to project/group'])
      end
    end

    context 'when event_type is disable_ai_catalog_agent' do
      let(:event_type) { 'disable_ai_catalog_agent' }

      it 'returns disable message' do
        expect(messages).to eq(['Removed AI agent from project/group'])
      end
    end
  end
end
