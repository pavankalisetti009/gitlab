# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkPrimaryVerificationWorker, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  it_behaves_like 'an idempotent worker' do
    let_it_be(:job_args) { 'Project' }
  end

  describe 'concurrent execution and deduplication' do
    let(:model_name) { 'Upload' }

    before do
      stub_current_geo_node(create(:geo_node, :primary))
      create_list(:upload, 10, :verification_succeeded)
    end

    it 'deduplicates jobs' do
      Sidekiq::Testing.fake! do
        described_class.clear

        3.times { described_class.perform_async(model_name) }

        expect(described_class.jobs.size).to eq(1)
        expect(described_class.jobs.first['args']).to eq([model_name])
      end
    end

    it 'schedules continuation jobs when time limit is reached' do
      Sidekiq::Testing.fake! do
        described_class.clear

        service = instance_double(Geo::BulkPrimaryVerificationService)
        allow(Geo::BulkPrimaryVerificationService).to receive(:new).and_return(service)
        allow(service).to receive(:execute) do
          described_class.perform_in(10.seconds, model_name)
          ServiceResponse.error(message: 'Time limit reached', payload: { status: :limit_reached })
        end

        described_class.new.perform(model_name)

        expect(described_class.jobs.size).to eq(1)
        expect(described_class.jobs.first['args']).to eq([model_name])
      end
    end
  end
end
