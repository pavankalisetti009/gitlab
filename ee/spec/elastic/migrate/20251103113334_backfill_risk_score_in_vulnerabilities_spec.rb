# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251103113334_backfill_risk_score_in_vulnerabilities.rb')

RSpec.describe BackfillRiskScoreInVulnerabilities, feature_category: :vulnerability_management do
  let(:version) { 20251103113334 }

  describe 'migration', :elastic_delete_by_query, :sidekiq_inline do
    include_examples 'migration reindex based on schema_version' do
      let(:expected_throttle_delay) { 15.seconds }
      let(:expected_batch_size) { 10_000 }

      let(:objects) do
        create_list(:vulnerability_read, 3)
      end
    end
  end
end
