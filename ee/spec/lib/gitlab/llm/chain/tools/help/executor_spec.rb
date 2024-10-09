# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::Help::Executor, feature_category: :duo_chat do
  let_it_be(:user) { build_stubbed(:user) }
  let(:command_name) { '/help' }
  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }

  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: nil, resource: nil, ai_request: ai_request_double
    )
  end

  let(:expected_slash_commands) do
    {
      '/help' => {
        description: 'Explain the current vulnerability.'
      }
    }
  end

  let(:command) do
    instance_double(Gitlab::Llm::Chain::SlashCommand, :command, platform_origin: platform_origin)
  end

  subject(:tool) { described_class.new(context: context, options: {}, command: command) }

  describe '#name' do
    it 'returns tool name' do
      expect(described_class::NAME).to eq('Help')
    end

    it 'returns resource name' do
      expect(described_class::RESOURCE_NAME).to eq(nil)
    end
  end

  describe '#execute' do
    context 'when request is from IDE' do
      let(:platform_origin) { Gitlab::Llm::Chain::SlashCommand::VS_CODE_EXTENSION }

      it 'returns IDE copy' do
        expect(tool.execute.content).to eq(described_class::IDE_COPY)
      end
    end

    context 'when request is from web' do
      let(:platform_origin) { Gitlab::Llm::Chain::SlashCommand::WEB }

      it 'returns IDE copy' do
        expect(tool.execute.content).to eq(described_class::WEB_COPY)
      end
    end
  end
end
