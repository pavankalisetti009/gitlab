# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UsageEvent, feature_category: :value_stream_management do
  let(:model_class) do
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include Ai::UsageEvent

      self.clickhouse_table_name = 'test_table'

      attribute :user
      attribute :event, :string
      attribute :timestamp, :datetime
      attribute :payload
    end

    # rubocop:disable RSpec/LeakyConstantDeclaration -- its a dynamic class
    klass::EVENTS = { 'test_event' => 1 }.freeze
    klass::PAYLOAD_ATTRIBUTES = %w[foo].freeze
    # rubocop:enable RSpec/LeakyConstantDeclaration
    klass
  end

  let(:event) { model_class.new(attributes.with_indifferent_access) }
  let(:attributes) { { user: user, timestamp: '2021-01-01'.to_datetime, event: 'test_event' } }
  let(:user) { build_stubbed(:user) }

  describe '#to_clickhouse_csv_row' do
    it 'returns 3 required fields' do
      expect(event.to_clickhouse_csv_row).to eq({
        user_id: user.id,
        timestamp: '2021-01-01'.to_datetime.to_i,
        event: 1
      })
    end
  end

  describe '.related_event?' do
    it 'is true for events from EVENTS const' do
      expect(model_class.related_event?('test_event')).to be_truthy
      expect(model_class.related_event?('foo')).to be_falsey
    end
  end
end
