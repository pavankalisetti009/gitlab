# frozen_string_literal: true

module Orderable # rubocop:disable Gitlab/BoundedContexts -- general purpose concern
  extend ActiveSupport::Concern

  included do
    scope :order_by_primary_key, -> { order(primary_key) }
  end
end
