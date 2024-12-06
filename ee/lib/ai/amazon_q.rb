# frozen_string_literal: true

module Ai
  module AmazonQ
    # NOTE: This module is under development. See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/174614
    class << self
      def feature_available?
        ::Feature.enabled?(:amazon_q_integration, nil) && License.feature_available?(:amazon_q)
      end

      def connected?
        return false unless feature_available?

        Ai::Setting.instance.amazon_q_ready
      end
    end
  end
end
