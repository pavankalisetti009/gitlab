# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251001130713_backfill_token_status_in_vulnerabilities.rb')

RSpec.describe BackfillTokenStatusInVulnerabilities, feature_category: :vulnerability_management do
  let(:version) { 20251001130713 }

  describe 'migration', :elastic_delete_by_query, :sidekiq_inline do
    before do
      allow(::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker).to receive(:perform_async)
    end

    include_examples 'migration reindex based on schema_version' do
      let(:expected_throttle_delay) { 15.seconds }
      let(:expected_batch_size) { 10_000 }

      let(:objects) do
        create_list(:vulnerability_read, 3)
      end
    end
  end
end
