# frozen_string_literal: true

module EE
  module RepositoryCheck
    module BatchWorker
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      override :perform
      def perform(shard_name)
        super unless ::Gitlab::Geo.secondary?
      end
    end
  end
end
