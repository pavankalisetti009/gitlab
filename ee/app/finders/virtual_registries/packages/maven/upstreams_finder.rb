# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      class UpstreamsFinder
        def initialize(group, params = {})
          @group = group
          @params = params
        end

        def execute
          upstreams = ::VirtualRegistries::Packages::Maven::Upstream.for_group(@group)

          upstreams = filter_by_upstream_name(upstreams) if params[:upstream_name].present?

          upstreams
        end

        private

        attr_reader :params

        def filter_by_upstream_name(upstreams)
          upstreams.search_by_name(params[:upstream_name])
        end
      end
    end
  end
end
