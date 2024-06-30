# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/tasks/gitlab/tokens/manage_expiry_task'

RSpec.describe 'Tasks::Gitlab::Tokens::ManageExpiryTask', feature_category: :system_access do
  # rubocop:disable RSpec/AvoidTestProf -- this is not a migration spec
  let_it_be(:expires_at) { Date.today + 364.days }
  let_it_be(:user) { create(:user) }
  let_it_be(:migration_status) do
    create(:batched_background_migration, :finished,
      job_class_name: 'CleanupPersonalAccessTokensWithNilExpiresAt',
      table_name: 'personal_access_tokens',
      column_name: 'id')
  end
  # rubocop:enable RSpec/AvoidTestProf

  let!(:personal_access_token1) { create(:personal_access_token, user: user, expires_at: expires_at) }
  let!(:personal_access_token2) { create(:personal_access_token, user: user, expires_at: expires_at) }
  let!(:personal_access_token3) { create(:personal_access_token, user: user, expires_at: expires_at + 1.day) }

  subject(:task) { Tasks::Gitlab::Tokens::ManageExpiryTask.new }

  describe '.analyze' do
    it 'calls the expected methods' do
      expect(task).to receive(:show_pat_expires_at_migration_status)
      expect(task).to receive(:show_most_common_pat_expiration_dates)

      task.analyze
    end
  end

  describe '.edit' do
    it 'calls analyze and prompts for action' do
      expect(task).to receive(:analyze).at_least(:once)
      expect(task).to receive(:prompt_action).at_least(:once).and_return(false)

      task.edit
    end
  end

  describe '.show_pat_expires_at_migration_status' do
    it 'prints the migration status' do
      expect { task.send(:show_pat_expires_at_migration_status) }.to output(
        /Started at: #{migration_status[:started_at]}\nFinished  : #{migration_status[:finished_at]}/).to_stdout
    end
  end

  describe '.show_most_common_pat_expiration_dates' do
    let(:second) { personal_access_token3.expires_at }

    it 'shows the two groups of expiration dates' do
      expect { task.send(:show_most_common_pat_expiration_dates) }.to output(
        /#{expires_at}.*\|\s+2\s+\|\n\|\s+#{second}\s+\|\s+1\s+/).to_stdout
    end
  end

  describe '.extend_expiration_date' do
    context 'with no max personal access token lifetime set' do
      it 'extends the expiration date for selected tokens' do
        new_date = expires_at + 1.day
        default_date = expires_at + 365.days
        prompt = instance_double(TTY::Prompt)

        expect(task).to receive(:prompt_expiration_date_selection).and_return(expires_at)
        expect(TTY::Prompt).to receive(:new).and_return(prompt)
        expect(prompt).to receive(:ask).with(anything, default: default_date).and_return(new_date.to_s)
        expect(prompt).to receive(:yes?).and_return(true)
        expect(task).to receive(:update_tokens_with_expiration).with(expires_at, new_date).and_call_original

        expect { task.send(:extend_expiration_date) }.to output(/Updated 2 tokens!/).to_stdout

        expect(personal_access_token1.reload.expires_at).to eq(new_date)
        expect(personal_access_token2.reload.expires_at).to eq(new_date)
      end
    end

    context 'with max personal access token token lifetime set' do
      before do
        stub_application_setting(max_personal_access_token_lifetime: 30)
      end

      it 'asks with the max_personal_access_token_lifetime default' do
        new_date = expires_at + 29.days
        default_date = expires_at + 30.days
        prompt = instance_double(TTY::Prompt)

        expect(task).to receive(:prompt_expiration_date_selection).and_return(expires_at)
        expect(TTY::Prompt).to receive(:new).and_return(prompt)
        expect(prompt).to receive(:ask).with(anything, default: default_date).and_return(new_date.to_s)

        expect(prompt).to receive(:yes?).and_return(true)
        expect(task).to receive(:update_tokens_with_expiration).with(expires_at, new_date).and_call_original

        expect { task.send(:extend_expiration_date) }.to output(/Updated 2 tokens!/).to_stdout

        expect(personal_access_token1.reload.expires_at).to eq(new_date)
        expect(personal_access_token2.reload.expires_at).to eq(new_date)
      end
    end
  end
end
