# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Parsers
        module Sbom
          module License
            module Common
              extend ActiveSupport::Concern
              extend ::Gitlab::Utils::Override

              override :parse
              def parse
                license = data['license']

                return if license.blank? || license.values_at('id', 'name').all?(&:blank?)

                check_license_name!(license)
                parsed_license(license)
              end

              private

              def check_license_name!(license)
                # Trivy 0.65.0 has a bug where it puts license identifiers in the name field.
                # To preserve license functionality for this specific version, we check if the name
                # is a valid SPDX ID and move it to the correct field if so.
                return unless ::Sbom::SPDX.valid_identifier?(license['name'])

                license['id'] = license.delete('name')
              end
            end
          end
        end
      end
    end
  end
end
