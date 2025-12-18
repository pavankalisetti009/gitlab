# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkMarkVerificationPendingBatchWorker, :geo, feature_category: :geo_replication do
  include_examples 'an idempotent worker' do
    let(:job_args) { [Geo::CiSecureFileRegistry.name] }
  end
end
