# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::EventsCount, feature_category: :value_stream_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }

  it { is_expected.to validate_presence_of(:organization_id) }
  it { is_expected.to validate_presence_of(:user_id) }
  it { is_expected.to validate_presence_of(:events_date) }
  it { is_expected.to validate_presence_of(:event) }
  it { is_expected.to validate_presence_of(:total_occurrences) }
  it { is_expected.to validate_numericality_of(:total_occurrences).is_greater_than_or_equal_to(0) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:namespace).optional }

  it 'uses id as the primary key' do
    expect(described_class.primary_key).to eq('id')
  end

  it 'has 3 months data retention' do
    expect(described_class.partitioning_strategy.retain_for).to eq(3.months)
  end

  describe 'enum event' do
    it 'defines event enum based on AI::UsageEvent events' do
      expect(described_class.events).to eq(Ai::UsageEvent.events)
    end
  end
end
