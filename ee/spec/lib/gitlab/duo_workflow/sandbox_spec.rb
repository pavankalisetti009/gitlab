# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoWorkflow::Sandbox, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }

  let(:duo_workflow_service_url) { 'https://duo-workflow.example.com:443' }

  subject(:sandbox) do
    described_class.new(
      current_user: user,
      duo_workflow_service_url: duo_workflow_service_url
    )
  end

  describe '#wrap_command' do
    let(:command) { '/tmp/duo-workflow-executor' }

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(ai_duo_agent_platform_network_firewall: true)
      end

      it 'wraps the command with SRT sandbox', :aggregate_failures do
        result = sandbox.wrap_command(command)

        expect(result).to be_an(Array)
        expect(result.length).to eq(18)

        expect(result[0]).to eq('if which srt > /dev/null; then')
        expect(result[1]).to eq('  echo "SRT found, creating config..."')
        expect(result[2]).to include("echo '")
        expect(result[2]).to include('/tmp/srt-settings.json')
        expect(result[3]).to eq('  echo "Testing SRT sandbox capabilities..."')
        expect(result[4]).to eq('  if srt --settings /tmp/srt-settings.json true 2>/dev/null; then')
        expect(result[5]).to eq("    echo \"SRT sandbox test successful, running command: #{command}\"")
        expect(result[6]).to eq("    srt --settings /tmp/srt-settings.json #{command}")
        expect(result[7]).to eq('  else')
        expect(result[8]).to include("    echo \"Warning: SRT found but can't create sandbox")
        expect(result[9]).to include('    echo "For more details visit: https://docs.gitlab.com')
        expect(result[10]).to eq("    #{command}")
        expect(result[11]).to eq('  fi')
        expect(result[12]).to eq('else')
        expect(result[13]).to include('  echo "Warning: srt is not installed or not in PATH')
        expect(result[14]).to include('  echo "For more details visit: https://docs.gitlab.com')
        expect(result[15]).to eq("  #{command}")
        expect(result[16]).to eq('fi')
        expect(result[17]).to eq('echo "Command execution completed with exit code: $?"')
      end

      it 'includes SRT configuration in the wrapped command' do
        result = sandbox.wrap_command(command)
        config_line = result[2]

        expect(config_line).to include('network')
        expect(config_line).to include('allowedDomains')
        expect(config_line).to include('filesystem')
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(ai_duo_agent_platform_network_firewall: false)
      end

      it 'returns the command without wrapping' do
        expect(sandbox.wrap_command(command)).to eq([command])
      end
    end
  end

  describe '#environment_variables' do
    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(ai_duo_agent_platform_network_firewall: true)
      end

      it 'returns SRT-specific environment variables' do
        expect(sandbox.environment_variables).to eq({
          NPM_CONFIG_CACHE: "/tmp/.npm-cache",
          GITLAB_LSP_STORAGE_DIR: "/tmp"
        })
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(ai_duo_agent_platform_network_firewall: false)
      end

      it 'returns an empty hash' do
        expect(sandbox.environment_variables).to eq({})
      end
    end
  end

  describe 'SRT configuration' do
    before do
      stub_feature_flags(ai_duo_agent_platform_network_firewall: true)
      allow(Gitlab.config.gitlab).to receive(:url).and_return('https://gitlab.example.com')
    end

    it 'includes allowed domains in the configuration' do
      result = sandbox.wrap_command('/tmp/executor')
      config_line = result[2]

      expect(config_line).to include('host.docker.internal')
      expect(config_line).to include('localhost')
      expect(config_line).to include('gitlab.example.com')
      expect(config_line).to include('*.gitlab.example.com')
      expect(config_line).to include('duo-workflow.example.com')
    end

    it 'includes filesystem restrictions in the configuration' do
      result = sandbox.wrap_command('/tmp/executor')
      config_line = result[2]

      expect(config_line).to include('~/.ssh')
      expect(config_line).to include('/tmp/')
    end

    it 'includes network restrictions in the configuration' do
      result = sandbox.wrap_command('/tmp/executor')
      config_line = result[2]

      expect(config_line).to include('/var/run/docker.sock')
      expect(config_line).to include('allowLocalBinding')
    end
  end

  describe 'domain extraction' do
    before do
      stub_feature_flags(ai_duo_agent_platform_network_firewall: true)
      allow(Gitlab.config.gitlab).to receive(:url).and_return('https://gitlab.example.com')
    end

    context 'with blank or nil URLs' do
      it 'handles blank duo_workflow_service_url' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: ''
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('gitlab.example.com')
        expect(config_line).to include('localhost')
      end

      it 'handles nil duo_workflow_service_url' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: nil
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('gitlab.example.com')
        expect(config_line).to include('localhost')
      end
    end

    context 'with full URI formats' do
      it 'extracts domain from https URL with port' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: 'https://example.com:443'
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('example.com')
      end

      it 'extracts domain from http URL' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: 'http://service.example.com'
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('service.example.com')
      end

      it 'extracts domain from URL with path' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: 'https://example.com/path/to/resource'
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('example.com')
      end
    end

    context 'with host:port format (no scheme)' do
      it 'extracts domain from host:port format' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: 'example.com:50052'
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('example.com')
      end

      it 'extracts domain from grpc service with port' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: 'grpc.example.com:50052'
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('grpc.example.com')
      end

      it 'extracts domain from localhost:port format' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: 'localhost:8080'
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('localhost')
      end

      it 'extracts domain from IP:port format' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: '192.168.1.1:3000'
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('192.168.1.1')
      end
    end

    context 'with plain hostnames' do
      it 'handles plain hostname without port' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: 'simple-hostname'
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('simple-hostname')
      end
    end

    context 'with invalid URI formats' do
      it 'handles invalid URI with colon by extracting first part' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: 'http://[invalid:malformed'
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('http')
      end

      it 'handles invalid URI without colon by using as-is' do
        sandbox = described_class.new(
          current_user: user,
          duo_workflow_service_url: 'invalid[bracket'
        )

        result = sandbox.wrap_command('/tmp/executor')
        config_line = result[2]

        expect(config_line).to include('invalid[bracket')
      end
    end
  end
end
