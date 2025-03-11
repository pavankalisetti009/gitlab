# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:zoekt namespace rake tasks', :silence_stdout, feature_category: :global_search do
  before do
    Rake.application.rake_require 'tasks/gitlab/zoekt'
  end

  shared_examples 'rake task executor task' do |task|
    it 'calls rake task executor' do
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(task)
      end

      run_rake_task("gitlab:zoekt:#{task}")
    end
  end

  describe 'gitlab:zoekt:info' do
    include_examples 'rake task executor task', :info
  end

  describe 'watch functionality in rake task' do
    it 'executes the rake task normally without watch mode when no interval is provided' do
      # We expect the task executor to be called directly
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(:info)
      end

      run_rake_task("gitlab:zoekt:info")
    end

    it 'executes the rake task normally when interval is zero' do
      # We expect the task executor to be called directly
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(:info)
      end

      run_rake_task("gitlab:zoekt:info", "0")
    end

    it 'executes the rake task normally when interval is negative' do
      # We expect the task executor to be called directly
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(:info)
      end

      run_rake_task("gitlab:zoekt:info", "-1")
    end
  end
end
