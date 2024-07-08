# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Backup::Cli::SourceContext do
  subject(:context) { described_class.new }

  let(:fake_gitlab_basepath) { Pathname.new(Dir.mktmpdir('gitlab', temp_path)) }

  before do
    allow(context).to receive(:gitlab_basepath).and_return(fake_gitlab_basepath)
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
end
