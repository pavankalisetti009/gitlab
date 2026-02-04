# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Tasks::Gitlab::AiGateway::Utils, feature_category: :duo_agent_platform do
  describe '.install!' do
    let(:path) { '/tmp/ai-gateway' }

    context 'when duo_workflow_service is enabled and dependencies are available' do
      before do
        allow(described_class).to receive_messages(
          duo_workflow_service_enabled?: true,
          prerequisites_met?: true,
          clone!: nil,
          checkout!: nil,
          install_project_deps!: nil,
          install_runtime_deps!: nil,
          mark_installed!: nil
        )
      end

      it 'calls clone, checkout, install_project_deps, install_runtime_deps, and mark_installed!' do
        described_class.install!(path: path)

        expect(described_class).to have_received(:clone!).with(path)
        expect(described_class).to have_received(:checkout!).with(path)
        expect(described_class).to have_received(:install_project_deps!).with(path)
        expect(described_class).to have_received(:install_runtime_deps!).with(path)
        expect(described_class).to have_received(:mark_installed!).with(path)
      end
    end

    context 'when duo_workflow_service is disabled' do
      before do
        allow(described_class).to receive(:duo_workflow_service_enabled?).and_return(false)
        allow(described_class).to receive(:clone!)
        allow(described_class).to receive(:checkout!)
        allow(described_class).to receive(:install_project_deps!)
        allow(described_class).to receive(:install_runtime_deps!)
      end

      it 'does not proceed with installation' do
        described_class.install!(path: path)

        expect(described_class).not_to have_received(:clone!)
        expect(described_class).not_to have_received(:checkout!)
        expect(described_class).not_to have_received(:install_project_deps!)
        expect(described_class).not_to have_received(:install_runtime_deps!)
      end
    end

    context 'when dependencies are not available' do
      before do
        allow(described_class).to receive_messages(
          duo_workflow_service_enabled?: true,
          prerequisites_met?: false,
          clone!: nil,
          checkout!: nil,
          install_project_deps!: nil,
          install_runtime_deps!: nil,
          mark_installed!: nil
        )
      end

      it 'does not proceed with installation' do
        described_class.install!(path: path)

        expect(described_class).not_to have_received(:clone!)
        expect(described_class).not_to have_received(:checkout!)
        expect(described_class).not_to have_received(:install_project_deps!)
        expect(described_class).not_to have_received(:install_runtime_deps!)
        expect(described_class).not_to have_received(:mark_installed!)
      end
    end
  end

  describe '.run_duo_workflow_service' do
    let(:path) { '/tmp/ai-gateway' }

    context 'when duo_workflow_service is enabled and installed' do
      context 'when mise is not available' do
        before do
          allow(described_class).to receive_messages(
            duo_workflow_service_enabled?: true,
            installed?: true,
            duo_workflow_service_port: '50053',
            mise_available?: false
          )
        end

        it 'spawns the duo workflow service with correct environment variables' do
          expect(Process).to receive(:spawn).with(
            hash_including(
              'AIGW_MOCK_MODEL_RESPONSES' => 'true',
              'AIGW_USE_AGENTIC_MOCK' => 'true',
              'PORT' => '50053',
              'DUO_WORKFLOW_AUTH__ENABLED' => 'false',
              'LANGCHAIN_ENDPOINT' => ''
            ),
            'poetry', '-C', path, 'run', 'duo-workflow-service'
          )

          described_class.run_duo_workflow_service(path: path)
        end
      end

      context 'when mise is available' do
        before do
          allow(described_class).to receive_messages(
            duo_workflow_service_enabled?: true,
            installed?: true,
            duo_workflow_service_port: '50053',
            mise_available?: true
          )
        end

        it 'spawns the duo workflow service with mise exec prefix' do
          expect(Process).to receive(:spawn).with(
            hash_including(
              'AIGW_MOCK_MODEL_RESPONSES' => 'true',
              'AIGW_USE_AGENTIC_MOCK' => 'true',
              'PORT' => '50053',
              'DUO_WORKFLOW_AUTH__ENABLED' => 'false',
              'LANGCHAIN_ENDPOINT' => ''
            ),
            'mise', '-C', path, 'exec', 'poetry', '--', 'poetry', '-C', path, 'run', 'duo-workflow-service'
          )

          described_class.run_duo_workflow_service(path: path)
        end
      end
    end

    context 'when duo_workflow_service is disabled' do
      before do
        allow(described_class).to receive(:duo_workflow_service_enabled?).and_return(false)
      end

      it 'does not spawn the service' do
        expect(Process).not_to receive(:spawn)

        described_class.run_duo_workflow_service(path: path)
      end
    end

    context 'when not installed' do
      before do
        allow(described_class).to receive_messages(
          duo_workflow_service_enabled?: true,
          installed?: false
        )
      end

      it 'does not spawn the service' do
        expect(Process).not_to receive(:spawn)

        described_class.run_duo_workflow_service(path: path)
      end
    end
  end

  describe '.latest_sha' do
    let(:repo_url) { described_class::REPO_URL }
    let(:branch) { 'main' }
    let(:sha) { 'abc123def456' }

    before do
      allow(described_class).to receive(:ai_gateway_repo_branch).and_return(branch)
    end

    context 'when git command succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(["#{sha}\trefs/heads/#{branch}", 0])
      end

      it 'returns the latest SHA' do
        result = described_class.latest_sha

        expect(result).to eq(sha)
      end

      it 'calls git ls-remote with correct parameters' do
        described_class.latest_sha

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including(repo_url, branch)
        )
      end
    end

    context 'when git command fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['error message', 1])
      end

      it 'raises an error' do
        expect { described_class.latest_sha }.to raise_error(
          /Failed to fetch the latest SHA of gitlab-ai-gateway/
        )
      end
    end
  end

  describe '.duo_workflow_service_port' do
    context 'when TEST_DUO_WORKFLOW_SERVICE_PORT environment variable is set' do
      before do
        stub_env('TEST_DUO_WORKFLOW_SERVICE_PORT', '9999')
      end

      it 'returns the environment variable value' do
        result = described_class.duo_workflow_service_port

        expect(result).to eq('9999')
      end
    end

    context 'when TEST_DUO_WORKFLOW_SERVICE_PORT environment variable is not set' do
      before do
        stub_env('TEST_DUO_WORKFLOW_SERVICE_PORT', nil)
      end

      it 'returns the default port' do
        result = described_class.duo_workflow_service_port

        expect(result).to eq(described_class::DEFAULT_PORT)
      end
    end
  end

  describe '.ai_gateway_repo_branch' do
    context 'when TEST_AI_GATEWAY_REPO_BRANCH environment variable is set' do
      before do
        stub_env('TEST_AI_GATEWAY_REPO_BRANCH', 'custom-branch')
      end

      it 'returns the environment variable value' do
        result = described_class.ai_gateway_repo_branch

        expect(result).to eq('custom-branch')
      end
    end

    context 'when TEST_AI_GATEWAY_REPO_BRANCH environment variable is not set' do
      before do
        stub_env('TEST_AI_GATEWAY_REPO_BRANCH', nil)
      end

      it 'returns the default branch' do
        result = described_class.ai_gateway_repo_branch

        expect(result).to eq(described_class::DEFAULT_BRANCH)
      end
    end
  end

  describe '.duo_workflow_service_enabled?' do
    context 'when TEST_DUO_WORKFLOW_SERVICE_ENABLED is not set to false' do
      before do
        stub_env('TEST_DUO_WORKFLOW_SERVICE_ENABLED', nil)
      end

      it 'returns true' do
        result = described_class.duo_workflow_service_enabled?

        expect(result).to be(true)
      end
    end

    context 'when TEST_DUO_WORKFLOW_SERVICE_ENABLED is set to false' do
      before do
        stub_env('TEST_DUO_WORKFLOW_SERVICE_ENABLED', 'false')
      end

      it 'returns false' do
        result = described_class.duo_workflow_service_enabled?

        expect(result).to be(false)
      end

      it 'prints a warning message' do
        expect do
          described_class.duo_workflow_service_enabled?
        end.to output(/\[WARN\] Some feature tests/).to_stdout
      end
    end
  end

  describe '.prerequisites_met?' do
    context 'when mise is available' do
      before do
        allow(described_class).to receive_messages(
          mise_available?: true,
          poetry_available?: false
        )
      end

      it 'returns true' do
        result = described_class.prerequisites_met?

        expect(result).to be(true)
      end
    end

    context 'when poetry is available' do
      before do
        allow(described_class).to receive_messages(
          mise_available?: false,
          poetry_available?: true
        )
      end

      it 'returns true' do
        result = described_class.prerequisites_met?

        expect(result).to be(true)
      end
    end

    context 'when neither mise nor poetry is available' do
      before do
        allow(described_class).to receive_messages(
          mise_available?: false,
          poetry_available?: false
        )
      end

      it 'returns false' do
        result = described_class.prerequisites_met?

        expect(result).to be(false)
      end

      it 'prints a warning message' do
        expect do
          described_class.prerequisites_met?
        end.to output(/\[WARN\] Some feature tests/).to_stdout
      end
    end
  end

  describe '.poetry_available?' do
    context 'when poetry command succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['Poetry (version 1.0.0)', 0])
      end

      it 'returns true' do
        result = described_class.poetry_available?

        expect(result).to be(true)
      end
    end

    context 'when poetry command fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['command not found', 127])
      end

      it 'returns nil (falsy)' do
        result = described_class.poetry_available?

        expect(result).to be_falsy
      end

      it 'prints an info message' do
        expect do
          described_class.poetry_available?
        end.to output(/\[INFO\] poetry is not available/).to_stdout
      end
    end

    context 'when poetry command is not found (Errno::ENOENT)' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_raise(Errno::ENOENT, 'No such file or directory')
      end

      it 'returns nil (falsy)' do
        result = described_class.poetry_available?

        expect(result).to be_falsy
      end

      it 'prints an info message with error details' do
        expect do
          described_class.poetry_available?
        end.to output(/\[INFO\] poetry is not available/).to_stdout
      end
    end
  end

  describe '.mise_available?' do
    context 'when mise command succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['mise 2024.1.0', 0])
      end

      it 'returns true' do
        result = described_class.mise_available?

        expect(result).to be(true)
      end
    end

    context 'when mise command fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['command not found', 127])
      end

      it 'returns nil (falsy)' do
        result = described_class.mise_available?

        expect(result).to be_falsy
      end

      it 'prints an info message' do
        expect do
          described_class.mise_available?
        end.to output(/\[INFO\] mise is not available/).to_stdout
      end
    end

    context 'when mise command is not found (Errno::ENOENT)' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_raise(Errno::ENOENT, 'No such file or directory')
      end

      it 'returns nil (falsy)' do
        result = described_class.mise_available?

        expect(result).to be_falsy
      end

      it 'prints an info message with error details' do
        expect do
          described_class.mise_available?
        end.to output(/\[INFO\] mise is not available/).to_stdout
      end
    end
  end

  describe '.clone!' do
    let(:path) { '/tmp/ai-gateway' }
    let(:repo_url) { described_class::REPO_URL }

    context 'when clone succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0])
      end

      it 'does not raise an error' do
        expect { described_class.clone!(path) }.not_to raise_error
      end

      it 'calls git clone with correct parameters' do
        described_class.clone!(path)

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including('clone', '--depth', '1', repo_url, path)
        )
      end

      it 'prints an info message' do
        expect do
          described_class.clone!(path)
        end.to output(/\[INFO\] Cloned AIGW repository/).to_stdout
      end
    end

    context 'when clone fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['fatal: repository not found', 128])
      end

      it 'raises an error' do
        expect { described_class.clone!(path) }.to raise_error(
          /git-clone failure of gitlab-ai-gateway repo/
        )
      end
    end
  end

  describe '.checkout!' do
    let(:path) { '/tmp/ai-gateway' }
    let(:branch) { 'main' }

    before do
      allow(described_class).to receive(:ai_gateway_repo_branch).and_return(branch)
    end

    context 'when fetch succeeds' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0])
      end

      it 'calls git fetch and checkout' do
        described_class.checkout!(path)

        expect(::Gitlab::Popen).to have_received(:popen).at_least(:twice)
      end

      it 'does not raise an error' do
        expect { described_class.checkout!(path) }.not_to raise_error
      end

      it 'prints an info message' do
        expect do
          described_class.checkout!(path)
        end.to output(/\[INFO\] Checked out AIGW repository ref/).to_stdout
      end
    end

    context 'when fetch fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_return(['fatal: unable to access repository', 128])
      end

      it 'raises an error' do
        expect { described_class.checkout!(path) }.to raise_error(
          /git-fetch failure of gitlab-ai-gateway branch/
        )
      end
    end

    context 'when checkout fails' do
      before do
        allow(::Gitlab::Popen).to receive(:popen).and_call_original
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0], ['error: pathspec did not match', 1])
      end

      it 'raises an error' do
        expect { described_class.checkout!(path) }.to raise_error(
          /git-checkout failure of gitlab-ai-gateway branch/
        )
      end
    end
  end

  describe '.install_project_deps!' do
    let(:path) { 'vendor/ai-gateway' }

    context 'when mise is available' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(true)
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0])
        allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
      end

      it 'does not raise an error' do
        expect { described_class.install_project_deps!(path) }.not_to raise_error
      end

      it 'calls mise install with correct path' do
        described_class.install_project_deps!(path)

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including('mise', '-C', '/app/vendor/ai-gateway', 'install')
        )
      end

      it 'prints an info message' do
        expect do
          described_class.install_project_deps!(path)
        end.to output(/\[INFO\] Installed AIGW project deps/).to_stdout
      end
    end

    context 'when mise is not available' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(false)
      end

      it 'returns early without calling popen' do
        expect(::Gitlab::Popen).not_to receive(:popen)

        described_class.install_project_deps!(path)
      end
    end

    context 'when mise install fails' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(true)
        allow(::Gitlab::Popen).to receive(:popen).and_return(['error: failed to install', 1])
        allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
      end

      it 'raises an error' do
        expect { described_class.install_project_deps!(path) }.to raise_error(
          /installation failure of AIGW project deps/
        )
      end
    end
  end

  describe '.install_runtime_deps!' do
    let(:path) { 'vendor/ai-gateway' }

    context 'when mise is available' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(true)
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0])
        allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
      end

      it 'does not raise an error' do
        expect { described_class.install_runtime_deps!(path) }.not_to raise_error
      end

      it 'calls poetry install with mise exec prefix' do
        described_class.install_runtime_deps!(path)

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including('mise', 'exec', 'poetry', '--', 'poetry', '-C', '/app/vendor/ai-gateway', 'install')
        )
      end

      it 'prints an info message' do
        expect do
          described_class.install_runtime_deps!(path)
        end.to output(/\[INFO\] Installed AIGW runtime deps/).to_stdout
      end
    end

    context 'when mise is not available' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(false)
        allow(::Gitlab::Popen).to receive(:popen).and_return(['', 0])
        allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
      end

      it 'does not raise an error' do
        expect { described_class.install_runtime_deps!(path) }.not_to raise_error
      end

      it 'calls poetry install without mise exec prefix' do
        described_class.install_runtime_deps!(path)

        expect(::Gitlab::Popen).to have_received(:popen).with(
          array_including('poetry', '-C', '/app/vendor/ai-gateway', 'install')
        )
      end

      it 'prints an info message' do
        expect do
          described_class.install_runtime_deps!(path)
        end.to output(/\[INFO\] Installed AIGW runtime deps/).to_stdout
      end
    end

    context 'when poetry install fails' do
      before do
        allow(described_class).to receive(:mise_available?).and_return(false)
        allow(::Gitlab::Popen).to receive(:popen).and_return(['error: failed to install', 1])
        allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
      end

      it 'raises an error' do
        expect { described_class.install_runtime_deps!(path) }.to raise_error(
          /installation failure of AIGW runtime deps/
        )
      end
    end
  end

  describe '.mark_installed!' do
    let(:path) { 'vendor/ai-gateway' }

    it 'creates the installed flag file' do
      allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
      allow(FileUtils).to receive(:touch)

      described_class.mark_installed!(path)

      expect(FileUtils).to have_received(:touch).with(Pathname.new('/app/vendor/ai-gateway/ai-gateway-installed.txt'))
    end
  end

  describe '.installed?' do
    let(:path) { 'vendor/ai-gateway' }

    context 'when installed flag file exists' do
      before do
        allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
        allow(File).to receive(:exist?).and_return(true)
      end

      it 'returns true' do
        result = described_class.installed?(path)

        expect(result).to be(true)
      end
    end

    context 'when installed flag file does not exist' do
      before do
        allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
        allow(File).to receive(:exist?).and_return(false)
      end

      it 'returns false' do
        result = described_class.installed?(path)

        expect(result).to be(false)
      end

      it 'prints a warning message' do
        expect do
          described_class.installed?(path)
        end.to output(/\[WARN\] Some feature tests/).to_stdout
      end
    end
  end
end
