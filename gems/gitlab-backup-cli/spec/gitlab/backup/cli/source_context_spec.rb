# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Backup::Cli::SourceContext do
  subject(:context) { described_class.new }

  let(:fake_gitlab_basepath) { Pathname.new(Dir.mktmpdir('gitlab', temp_path)) }

  before do
    allow(context).to receive(:gitlab_basepath).and_return(fake_gitlab_basepath)
    FileUtils.mkdir fake_gitlab_basepath.join('config')
  end

  after do
    fake_gitlab_basepath.rmtree
  end

  describe '#gitlab_version' do
    it 'returns the GitLab version from the VERSION file' do
      version_fixture = fixtures_path.join('VERSION')
      FileUtils.copy(version_fixture, fake_gitlab_basepath)

      expect(context.gitlab_version).to eq('17.0.3-ee')
    end
  end

  describe '#backup_basedir' do
    context 'with a relative path configured in gitlab.yml' do
      it 'returns a full path based on gitlab basepath' do
        use_gitlab_config_fixture('gitlab.yml')

        expect(context.backup_basedir).to eq(fake_gitlab_basepath.join('tmp/tests/backups'))
      end
    end

    context 'with full path configure in gitlab.yml' do
      it 'returns a full path as configured in gitlab.yml' do
        use_gitlab_config_fixture('gitlab-relativepaths.yml')

        expect(context.backup_basedir).to eq(Pathname('/tmp/gitlab/full/backups'))
      end
    end
  end

  def use_gitlab_config_fixture(fixture)
    gitlab_yml_fixture = fixtures_path.join(fixture)
    FileUtils.copy(gitlab_yml_fixture, fake_gitlab_basepath.join('config/gitlab.yml'))
  end
end
