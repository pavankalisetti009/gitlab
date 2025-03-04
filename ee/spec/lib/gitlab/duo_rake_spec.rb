# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:duo tasks', :gitlab_duo, :silence_stdout, feature_category: :duo_chat do
  include RakeHelpers

  before_all do
    Rake.application.rake_require 'tasks/gitlab/duo'
    Rake::Task.define_task(:environment)
  end

  describe 'duo:setup' do
    let(:setup_instance) do
      instance_double(Gitlab::Duo::Developments::Setup)
    end

    before do
      allow(Gitlab::Duo::Developments::Setup).to receive(:new).and_return(setup_instance)
      allow(setup_instance).to receive(:execute).and_return(true)
    end

    it 'creates a Gitlab::Duo::Developments::Setup instance with correct arguments' do
      Rake::Task['gitlab:duo:setup'].invoke('test')

      expect(Gitlab::Duo::Developments::Setup).to have_received(:new).with(hash_including(add_on: 'test'))
    end
  end
end
