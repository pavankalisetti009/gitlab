# frozen_string_literal: true

require_relative 'v1/table_helpers'

module Gitlab
  module BackgroundMigration
    module SpecHelpers
      # Version 1 of the batched background migration spec helpers
      #
      # This module provides a collection of helper utilities for writing
      # batched background migration specs with less boilerplate.
      #
      # @example Include all V1 helpers
      #   RSpec.describe Gitlab::BackgroundMigration::SomeMigration do
      #     include Gitlab::BackgroundMigration::SpecHelpers::V1
      #   end
      module V1
        extend ActiveSupport::Concern

        included do
          include TableHelpers
        end
      end
    end
  end
end
