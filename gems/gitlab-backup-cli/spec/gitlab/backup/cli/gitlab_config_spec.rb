# frozen_string_literal: true

RSpec.describe Gitlab::Backup::Cli::GitlabConfig do
  let(:config_fixture) { fixtures_path.join('gitlab.yml') }

  subject(:gitlab_config) { described_class.new(config_fixture) }

  describe '#initialize' do
    context 'when provided with a gitlab configuration file' do
      it 'loads the configuration' do
        expect(gitlab_config.keys).to include('test')
      end
    end
  end
end
