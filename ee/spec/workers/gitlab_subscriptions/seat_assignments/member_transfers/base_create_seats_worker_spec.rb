# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatAssignments::MemberTransfers::BaseCreateSeatsWorker, :saas, feature_category: :seat_cost_management do
  let(:worker) { described_class.new }

  describe '#collect_user_ids' do
    it 'raises NotImplementedError' do
      expect { worker.send(:collect_user_ids, double) }.to raise_error(NotImplementedError)
    end
  end

  describe '#find_source_by_id' do
    it 'raises NotImplementedError' do
      expect { worker.send(:find_source_by_id, double) }.to raise_error(NotImplementedError)
    end
  end
end
