# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::PageLayoutHelper, feature_category: :shared do
  describe '#duo_chat_panel_data' do
    let_it_be(:user) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for global_id
    let(:project) { build(:project) }
    let(:group) { build(:group) }

    before do
      allow(::Gitlab::Llm::TanukiBot).to receive_messages(user_model_selection_enabled?: false,
        agentic_mode_available?: false, root_namespace_id: 'root-123', resource_id: 'resource-456',
        chat_disabled_reason: nil)
      allow(::Gitlab::DuoWorkflow::Client).to receive(:metadata).and_return({ key: 'value' })
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(false)
    end

    it 'returns user global id' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:user_id]).to eq(user.to_global_id)
    end

    context 'when project is persisted' do
      let(:project) { create(:project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for persist check

      it 'returns project global id when project is persisted' do
        result = helper.duo_chat_panel_data(user, project, group)

        expect(result[:project_id]).to eq(project.to_global_id)
      end
    end

    it 'returns nil project id when project is not persisted' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:project_id]).to be_nil
    end

    it 'returns nil project id when project is nil' do
      result = helper.duo_chat_panel_data(user, nil, group)

      expect(result[:project_id]).to be_nil
    end

    context 'when group is persisted' do
      let(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for persist check

      it 'returns group global id when group is persisted' do
        result = helper.duo_chat_panel_data(user, project, group)

        expect(result[:namespace_id]).to eq(group.to_global_id)
      end
    end

    it 'returns nil namespace id when group is not persisted' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:namespace_id]).to be_nil
    end

    it 'returns nil namespace id when group is nil' do
      result = helper.duo_chat_panel_data(user, project, nil)

      expect(result[:namespace_id]).to be_nil
    end

    it 'returns root namespace id from TanukiBot' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:root_namespace_id]).to eq('root-123')
    end

    it 'returns resource id from TanukiBot' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:resource_id]).to eq('resource-456')
    end

    it 'returns metadata as JSON string' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:metadata]).to eq('{"key":"value"}')
    end

    it 'returns user model selection enabled as string' do
      allow(Gitlab::Llm::TanukiBot).to receive(:user_model_selection_enabled?).and_return(true)

      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:user_model_selection_enabled]).to eq('true')
    end

    it 'returns agentic available as string' do
      allow(Gitlab::Llm::TanukiBot).to receive(:agentic_mode_available?).and_return(true)

      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:agentic_available]).to eq('true')
    end

    it 'returns default chat title when AmazonQ is disabled' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:chat_title]).to eq(s_('GitLab Duo Chat'))
    end

    it 'returns AmazonQ chat title when AmazonQ is enabled' do
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(true)

      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:chat_title]).to eq(s_('GitLab Duo Chat with Amazon Q'))
    end

    it 'calls TanukiBot methods with correct parameters' do
      expect(Gitlab::Llm::TanukiBot).to receive(:user_model_selection_enabled?).with(user: user)
      expect(Gitlab::Llm::TanukiBot).to receive(:agentic_mode_available?).with(
        user: user, project: project, group: group
      )

      helper.duo_chat_panel_data(user, project, group)
    end

    it 'calls DuoWorkflow Client metadata with user' do
      expect(Gitlab::DuoWorkflow::Client).to receive(:metadata).with(user)

      helper.duo_chat_panel_data(user, project, group)
    end

    it 'returns chat_disabled_reason as empty string when chat is enabled' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:chat_disabled_reason]).to eq('')
    end

    context 'when chat is disabled for project' do
      before do
        allow(::Gitlab::Llm::TanukiBot).to receive(:chat_disabled_reason)
          .with(user: user, container: project)
          .and_return(:project)
      end

      it 'returns chat_disabled_reason as "project"' do
        result = helper.duo_chat_panel_data(user, project, nil)

        expect(result[:chat_disabled_reason]).to eq('project')
      end
    end

    context 'when chat is disabled for group' do
      before do
        allow(::Gitlab::Llm::TanukiBot).to receive(:chat_disabled_reason)
          .with(user: user, container: group)
          .and_return(:group)
      end

      it 'returns chat_disabled_reason as "group"' do
        result = helper.duo_chat_panel_data(user, nil, group)

        expect(result[:chat_disabled_reason]).to eq('group')
      end
    end

    context 'when group context is absent' do
      let(:default_namespace) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- for persist check

      before do
        allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(default_namespace)
      end

      it 'uses default namespace if project is absent' do
        result = helper.duo_chat_panel_data(user, nil, nil)

        expect(result[:namespace_id]).to eq(default_namespace.to_global_id)
      end

      it 'does not use default namespace when project is present' do
        expect(user.user_preference).not_to receive(:get_default_duo_namespace)

        result = helper.duo_chat_panel_data(user, project, nil)

        expect(result[:namespace_id]).to be_nil
      end
    end
  end

  describe '#agentic_unavailable_message' do
    let(:user) { build(:user) }
    let(:container) { build(:project) }
    let(:allowed) { false }
    let(:enablement_type) { nil }
    let(:duo_response) do
      instance_double(Ai::UserAuthorizable::Response, enablement_type: enablement_type, allowed?: allowed)
    end

    def expect_generic_message(result)
      expect(result).to eq(
        "You don't currently have access to Duo Chat, please contact your GitLab administrator."
      )
    end

    before do
      allow(user).to receive(:allowed_to_use).with(:duo_chat).and_return(duo_response)
    end

    context 'when agentic is available' do
      it 'returns nil' do
        result = helper.agentic_unavailable_message(user, container, true)

        expect(result).to be_nil
      end
    end

    context 'when agentic is not available' do
      context 'when under SaaS', :saas do
        context 'when container is present' do
          let(:allowed) { false }

          it 'returns access denied message' do
            result = helper.agentic_unavailable_message(user, container, false)

            expect_generic_message(result)
          end
        end

        context 'when container is nil' do
          let(:allowed) { true }

          context 'with duo_pro enablement' do
            let(:enablement_type) { 'duo_pro' }

            it 'links to preference page' do
              result = helper.agentic_unavailable_message(user, nil, false)

              expect(result).to include('Duo Agentic Chat is not available at the moment in this page.')
              expect(result).to include('Default GitLab Duo namespace')
              expect(result).to include(
                '/-/profile/preferences#user_user_preference_attributes_default_duo_add_on_assignment_id'
              )
            end
          end

          context 'with duo_core enablement' do
            let(:enablement_type) { 'duo_core' }
            let(:message) do
              'Duo Agentic Chat is not available in this page, ' \
                'please visit a project page to have access to chat.'
            end

            it 'returns project page message' do
              result = helper.agentic_unavailable_message(user, nil, false)

              expect(result).to eq(message)
            end
          end

          context 'when user is not allowed chat at all' do
            it 'returns generic message' do
              result = helper.agentic_unavailable_message(user, nil, false)

              expect_generic_message(result)
            end
          end
        end
      end

      context 'when under self-managed' do
        it 'returns nil' do
          result = helper.agentic_unavailable_message(user, nil, false)

          expect(result).to be_nil
        end
      end
    end
  end
end
