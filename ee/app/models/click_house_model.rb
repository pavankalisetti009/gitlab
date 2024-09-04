# frozen_string_literal: true

module ClickHouseModel
  extend ActiveSupport::Concern

  include ActiveModel::Model
  include ActiveModel::Attributes

  included do
    class << self
      attr_accessor :clickhouse_table_name

      def related_event?(event_name)
        const_defined?(:EVENTS) && event_name.in?(const_get(:EVENTS, false))
      end
    end
  end

  def store_to_clickhouse
    return false unless valid?

    ::ClickHouse::WriteBuffer.add(self.class.clickhouse_table_name, to_clickhouse_csv_row)
  end

  def to_clickhouse_csv_row
    raise NoMethodError # must be overloaded in descendants
  end
end
