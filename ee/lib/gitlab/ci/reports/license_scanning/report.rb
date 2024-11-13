# frozen_string_literal: true

module Gitlab
  module Ci
    module Reports
      module LicenseScanning
        class Report
          delegate :empty?, :fetch, :[], to: :found_licenses
          attr_accessor :version

          def initialize(version: '1.0')
            @version = version
            @found_licenses = {}
          end

          def major_version
            version.split('.')[0]
          end

          def licenses
            found_licenses.values.sort_by { |license| license.name.downcase }
          end

          def license_names
            found_licenses.values.map(&:name)
          end

          def add_license(id:, name:, url: '')
            add(::Gitlab::Ci::Reports::LicenseScanning::License.new(id: id, name: name, url: url))
          end

          def add(license)
            found_licenses[license.canonical_id] ||= license
          end

          def dependency_names
            found_licenses.values.flat_map(&:dependencies).map(&:name).uniq
          end

          def by_license_name(name)
            licenses.find { |license| license.name.casecmp?(name) }
          end

          def diff_with(other_report)
            base = self.licenses
            head = other_report&.licenses || []

            {
              added: (head - base),
              unchanged: (base & head),
              removed: (base - head)
            }
          end

          private

          attr_reader :found_licenses
        end
      end
    end
  end
end
