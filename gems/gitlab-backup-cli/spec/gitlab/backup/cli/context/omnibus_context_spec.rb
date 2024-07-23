# frozen_string_literal: true

RSpec.describe Gitlab::Backup::Cli::Context::OmnibusContext do
  subject(:context) { described_class.new }

  let(:fake_gitlab_basepath) { Pathname.new(Dir.mktmpdir('gitlab', temp_path)) }
  let(:fake_omnibus_config_basepath) { Pathname.new(Dir.mktmpdir('omnibus', temp_path)) }
  let(:omnibus_config_path) { fake_omnibus_config_basepath.join('gitlab-backup-cli-config.yml') }

  before do
    allow(context).to receive(:gitlab_basepath).and_return(fake_gitlab_basepath)
    FileUtils.mkdir fake_gitlab_basepath.join('config')
  end

  after do
    fake_gitlab_basepath.rmtree
    fake_omnibus_config_basepath.rmtree
  end

  describe '.available?' do
    it 'returns false when no OMNIBUS_CONFIG_ENV is present' do
      stub_omnibus_config_env('')

      expect(described_class.available?).to be_falsey
    end

    it 'returns false when OMNIBUS_CONFIG_ENV points to nonexistent file' do
      stub_omnibus_config_env(fake_omnibus_config_basepath.join('something.yml'))

      expect(described_class.available?).to be_falsey
    end

    it 'returns true when OMNIBUS_CONFIG_ENV points to an existing file' do
      use_omnibus_config_fixture('gitlab-backup-cli-config.yml')

      expect(described_class.available?).to be_truthy
    end
  end

  describe '#omnibus_config' do
    subject(:omnibus_config) { context.send(:omnibus_config) }

    it 'raises an exception when it cant load the configuration file' do
      expect { omnibus_config }.to raise_error(::Gitlab::Backup::Cli::Error)
    end

    context 'with a correct configuration file' do
      before do
        use_omnibus_config_fixture('gitlab-backup-cli-config.yml')
      end

      it 'returns an OmnibusConfig instance when configuration file can be loaded' do
        expect(omnibus_config).to be_a(Gitlab::Backup::Cli::Context::OmnibusConfig)
      end

      it 'loads all expected configuration data' do
        expected_hash = {
          version: 1,
          installation_type: 'omnibus',
          gitlab: {
            config_path: '/var/opt/gitlab/gitlab-rails/etc/gitlab.yml'
          },
          database: {
            config_path: '/var/opt/gitlab/gitlab-rails/etc/database.yml'
          }
        }
        expect(omnibus_config.to_h).to eq(expected_hash)
      end
    end
  end

  def stub_omnibus_config_env(value)
    stub_env(described_class::OMNIBUS_CONFIG_ENV, value)
  end

  def use_omnibus_config_fixture(fixture)
    omnibus_yml_fixture = fixtures_path.join('omnibus', fixture)
    FileUtils.copy(omnibus_yml_fixture, omnibus_config_path)

    stub_omnibus_config_env(omnibus_config_path)
  end
end
