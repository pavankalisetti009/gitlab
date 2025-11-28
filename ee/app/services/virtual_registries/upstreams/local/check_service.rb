# frozen_string_literal: true

module VirtualRegistries
  module Upstreams
    module Local
      class CheckService < ::VirtualRegistries::Upstreams::CheckBaseService
        include Gitlab::Utils::StrongMemoize

        NO_FINDER_INSTANCE_ERROR = ServiceResponse.error(
          message: 'Upstream class not supported',
          reason: :upstream_class_not_supported
        ).freeze

        FINDERS_CLASSES_MAP = {
          ::VirtualRegistries::Packages::Maven::Upstream => ::Packages::Maven::GroupsAndProjectsPackageFilesFinder
        }.freeze

        private

        def check
          return NO_FINDER_INSTANCE_ERROR unless finder_class
          return ServiceResponse.success(payload: upstream_and_file) if upstream_and_file

          ERRORS[:file_not_found_on_upstreams]
        end

        def upstream_and_file
          upstreams.each do |upstream|
            package_file = find_package_file_for(upstream:)

            return { upstream:, package_file: } if package_file
          end

          nil
        end
        strong_memoize_attr :upstream_and_file

        def find_package_file_for(upstream:)
          package_files.find do |file|
            if upstream.local_project?
              file[:project_id] == upstream.local_project_id
            elsif upstream.local_group?
              traversal_ids = traversal_ids_map[file[:project_id]]
              traversal_ids && upstream.local_group_id.in?(traversal_ids)
            end
          end
        end

        def traversal_ids_map
          # rubocop:disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- package_files is an array(L65), not an ActiveRecord relation
          Project
            .group_by_namespace_traversal_ids(package_files.pluck(:project_id))
            .invert
            .transform_keys(&:first)
          # rubocop:enable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit
        end
        strong_memoize_attr :traversal_ids_map

        def package_files
          finder_class.new(path:, project_ids:, group_ids:)
            .execute
            .to_a
        end
        strong_memoize_attr :package_files

        def finder_class
          FINDERS_CLASSES_MAP[upstreams.first.class]
        end

        def project_ids
          upstreams.filter_map(&:local_project_id)
        end

        def group_ids
          upstreams.filter_map(&:local_group_id)
        end
      end
    end
  end
end
