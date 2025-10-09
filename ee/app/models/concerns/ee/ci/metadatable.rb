# frozen_string_literal: true

module EE
  module Ci
    module Metadatable
      extend ActiveSupport::Concern

      def secrets
        read_metadata_attribute(nil, :secrets, :secrets, {}).deep_stringify_keys
      end

      def secrets?
        secrets.present?
      end
    end
  end
end
