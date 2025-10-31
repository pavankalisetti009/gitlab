# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      class HandleFileRequestService < ::VirtualRegistries::BaseService
        include Gitlab::InternalEventsTracking

        DIGEST_EXTENSIONS = %w[.sha1 .md5].freeze
        PERMISSIONS_CACHE_TTL = 5.minutes

        ERRORS = BASE_ERRORS.merge(
          unauthorized: ServiceResponse.error(message: 'Unauthorized', reason: :unauthorized),
          no_upstreams: ServiceResponse.error(message: 'No upstreams set', reason: :no_upstreams),
          fips_unsupported_md5: ServiceResponse.error(
            message: 'MD5 digest is not supported when FIPS is enabled',
            reason: :fips_unsupported_md5
          ),
          upstream_not_available: ServiceResponse.error(
            message: 'Upstream not available',
            reason: :upstream_not_available
          )
        ).freeze

        def execute
          return ERRORS[:path_not_present] unless path.present?
          return ERRORS[:unauthorized] unless allowed?
          return ERRORS[:no_upstreams] if registry.upstreams.empty?

          if digest_request?
            download_cache_entry_digest
          elsif cache_response_still_valid?
            download_cache_entry
          else
            build_workhorse_upload_url_response
          end

        rescue *::Gitlab::HTTP::HTTP_ERRORS
          return download_cache_entry if cache_entry

          ERRORS[:upstream_not_available]
        end

        private

        def cache_response_still_valid?
          return false unless cache_entry
          return true unless cache_entry.stale?

          # cache entry with no etag can't be checked
          return false if cache_entry.upstream_etag.blank?

          response = head_upstream(upstream: cache_entry.upstream)

          return false unless cache_entry.upstream_etag == response.headers['etag']

          cache_entry.update_column(:upstream_checked_at, Time.current)
          true
        end

        def cache_entry
          VirtualRegistries::Packages::Maven::Cache::Entry
            .default
            .for_group(registry.group)
            .for_upstream(registry.upstreams)
            .find_by_relative_path(relative_path)
        end
        strong_memoize_attr :cache_entry

        def build_workhorse_upload_url_response
          return check_registry_upstreams_response unless upstream

          workhorse_upload_url_response(upstream: upstream)
        end

        def build_workhorse_send_url_response
          return check_registry_upstreams_response unless upstream

          workhorse_send_url_response(upstream: upstream)
        end

        def check_registry_upstreams_response
          ::VirtualRegistries::CheckUpstreamsService.new(
            registry: registry,
            params: { path: base_file_path }
          ).execute
        end
        strong_memoize_attr :check_registry_upstreams_response

        def upstream
          return unless check_registry_upstreams_response.success?

          check_registry_upstreams_response.payload[:upstream]
        end

        def head_upstream(upstream:)
          url = upstream.url_for(path)
          headers = upstream.headers

          ::Gitlab::HTTP.head(
            url,
            headers: headers,
            follow_redirects: true,
            timeout: NETWORK_TIMEOUT
          )
        end

        def download_cache_entry_digest
          digest_format = File.extname(path)[1..] # file extension without the leading dot
          return ERRORS[:fips_unsupported_md5] if digest_format == 'md5' && Gitlab::FIPS.enabled?

          unless cache_entry
            response = build_workhorse_send_url_response
            enqueue_create_cache_entry_job if response.success?
            return response
          end

          create_event(from_upstream: false)
          cache_entry.bump_downloads_count

          ServiceResponse.success(
            payload: {
              action: :download_digest,
              action_params: { digest: cache_entry["file_#{digest_format}"] }
            }
          )
        end

        def digest_request?
          File.extname(path).in?(DIGEST_EXTENSIONS)
        end
        strong_memoize_attr :digest_request?

        def allowed?
          return false unless current_user # anonymous users can't access virtual registries

          Rails.cache.fetch(permissions_cache_key, expires_in: PERMISSIONS_CACHE_TTL) do
            can?(current_user, :read_virtual_registry, registry)
          end
        end

        def permissions_cache_key
          [
            'virtual_registries',
            current_user.model_name.cache_key,
            current_user.id,
            'read_virtual_registry',
            'maven',
            registry.id
          ]
        end

        def path
          params[:path]
        end

        def base_file_path
          if digest_request?
            path.chomp(File.extname(path))
          else
            path
          end
        end

        def relative_path
          "/#{base_file_path}"
        end

        def download_cache_entry
          create_event(from_upstream: false)
          cache_entry.bump_downloads_count

          ServiceResponse.success(
            payload: {
              action: :download_file,
              action_params: {
                file: cache_entry.file,
                file_sha1: cache_entry.file_sha1,
                file_md5: cache_entry.file_md5,
                content_type: cache_entry.content_type
              }
            }
          )
        end

        def workhorse_upload_url_response(upstream:)
          create_event(from_upstream: true)

          ServiceResponse.success(
            payload: {
              action: :workhorse_upload_url,
              action_params: { url: upstream.url_for(path), upstream: upstream }
            }
          )
        end

        def workhorse_send_url_response(upstream:)
          create_event(from_upstream: true)

          ServiceResponse.success(
            payload: {
              action: :workhorse_send_url,
              action_params: { url: upstream.url_for(path) }
            }
          )
        end

        def create_event(from_upstream:)
          args = {
            namespace: registry.group,
            additional_properties: { label: from_upstream ? 'from_upstream' : 'from_cache' }
          }
          args[:user] = current_user if current_user.is_a?(User)
          track_internal_event('pull_maven_package_file_through_virtual_registry', **args)
        end

        def enqueue_create_cache_entry_job
          ::VirtualRegistries::Packages::Maven::CreateCacheEntryWorker.perform_async(
            upstream.id, base_file_path
          )
        end
      end
    end
  end
end
