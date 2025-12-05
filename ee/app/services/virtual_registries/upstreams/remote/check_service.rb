# frozen_string_literal: true

module VirtualRegistries
  module Upstreams
    module Remote
      class CheckService < ::VirtualRegistries::Upstreams::CheckBaseService
        MAX_CONCURRENCY = 3
        NETWORK_TIMEOUT = 5

        def initialize(upstreams:, params: {})
          super

          @hydra = Typhoeus::Hydra.new(max_concurrency: MAX_CONCURRENCY)
        end

        private

        attr_reader :hydra

        def check
          configure_hydra
          hydra.run

          return ERRORS[:file_not_found_on_upstreams] unless first_successful_index

          ServiceResponse.success(payload: { upstream: upstreams[first_successful_index] })
        end

        def configure_hydra
          upstreams.each_with_index do |upstream, index|
            request = Typhoeus::Request.new(
              upstream.url_for(path),
              headers: upstream.headers(path),
              method: :head,
              followlocation: true,
              timeout: NETWORK_TIMEOUT
            )

            request.on_complete do |response|
              # given that each url is checked in parallel, the order which we receive the
              # results are not guaranteed. Thus, we need to first record the result for
              # this index and then check the results array to know if we are in a
              # success state or not. If that's the case, we need to get which index
              # contains the first true value.
              results[index] = response.success?
              hydra.abort if first_successful_index
            end

            hydra.queue(request)
          end
        end
      end
    end
  end
end
