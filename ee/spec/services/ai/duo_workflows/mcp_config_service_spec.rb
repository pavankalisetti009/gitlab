# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::McpConfigService, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let(:gitlab_token) { 'test_gitlab_token_12345' }

  subject(:service) { described_class.new(user, gitlab_token) }

  describe '#execute' do
    it 'returns configuration hash with gitlab server' do
      result = service.execute

      expect(result).to be_a(Hash)
      expect(result).to have_key(:gitlab)
    end

    it 'includes gitlab MCP server configuration' do
      result = service.execute

      expect(result[:gitlab]).to match(
        Headers: {
          Authorization: "Bearer #{gitlab_token}"
        },
        Tools: described_class::GITLAB_ENABLED_TOOLS
      )
    end

    it 'includes proper authorization header with token' do
      result = service.execute

      expect(result[:gitlab][:Headers][:Authorization]).to eq("Bearer #{gitlab_token}")
    end

    it 'includes enabled tools list' do
      result = service.execute

      expect(result[:gitlab][:Tools]).to eq(['get_issue'])
    end

    context 'when mcp_client feature flag is disabled' do
      before do
        stub_feature_flags(mcp_client: false)
      end

      it 'returns nil' do
        result = service.execute

        expect(result).to be_nil
      end
    end

    context 'with different gitlab tokens' do
      it 'uses the provided token in authorization header' do
        custom_token = 'custom_token_xyz'
        custom_service = described_class.new(user, custom_token)

        result = custom_service.execute

        expect(result[:gitlab][:Headers][:Authorization]).to eq("Bearer #{custom_token}")
      end
    end
  end

  describe '#gitlab_enabled_tools' do
    it 'returns array of enabled tools' do
      result = service.gitlab_enabled_tools

      expect(result).to eq(['get_issue'])
    end

    it 'returns the GITLAB_ENABLED_TOOLS constant' do
      result = service.gitlab_enabled_tools

      expect(result).to eq(described_class::GITLAB_ENABLED_TOOLS)
    end

    context 'when mcp_client feature flag is disabled' do
      before do
        stub_feature_flags(mcp_client: false)
      end

      it 'returns empty array' do
        result = service.gitlab_enabled_tools

        expect(result).to eq([])
      end
    end
  end

  describe 'constant GITLAB_ENABLED_TOOLS' do
    it 'is defined with expected tools' do
      expect(described_class::GITLAB_ENABLED_TOOLS).to eq(['get_issue'])
    end
  end
end
