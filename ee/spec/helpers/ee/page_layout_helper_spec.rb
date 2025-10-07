# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::PageLayoutHelper, feature_category: :shared do
  describe '#duo_chat_panel_data' do
    let_it_be(:user) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for global_id
    let(:project) { build(:project) }
    let(:group) { build(:group) }

    before do
      allow(::Gitlab::Llm::TanukiBot).to receive_messages(user_model_selection_enabled?: false,
        agentic_mode_available?: false, root_namespace_id: 'root-123', resource_id: 'resource-456')
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
  end
end
