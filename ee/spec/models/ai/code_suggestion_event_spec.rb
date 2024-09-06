# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CodeSuggestionEvent, feature_category: :code_suggestions do
  subject(:event) { described_class.new(attributes) }

  let(:attributes) { { event: 'code_suggestion_shown_in_ide' } }
  let(:user) { build_stubbed(:user, :with_namespace) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:timestamp) }
    it { is_expected.to validate_presence_of(:organization_id) }
  end

  describe '#timestamp', :freeze_time do
    it 'defaults to current time' do
      expect(event.timestamp).to eq(DateTime.current)
    end

    it 'properly converts from string' do
      expect(described_class.new(timestamp: DateTime.current.to_s).timestamp).to eq(DateTime.current)
    end
  end

  describe '#organization_id' do
    subject(:event) { described_class.new(user: user).tap(&:valid?) }

    it 'populates organization_id from user namespace' do
      expect(event.organization_id).to be_present
      expect(event.organization_id).to eq(user.namespace.organization_id)
    end
  end

  describe '#to_clickhouse_csv_row', :freeze_time do
    let(:attributes) do
      super().merge(user: user, timestamp: 1.day.ago, suggestion_size: 3, language: 'foo', unique_tracking_id: 'bar')
    end

    it 'returns serialized attributes hash' do
      expect(event.to_clickhouse_csv_row).to eq({
        user_id: user.id,
        event: described_class::EVENTS['code_suggestion_shown_in_ide'],
        timestamp: 1.day.ago.to_f,
        suggestion_size: 3,
        language: 'foo',
        unique_tracking_id: 'bar'
      })
    end
  end
end
