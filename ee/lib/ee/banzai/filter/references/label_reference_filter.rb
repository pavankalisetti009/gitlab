# frozen_string_literal: true

module EE
  module Banzai
    module Filter
      module References
        module LabelReferenceFilter
          extend ::Gitlab::Utils::Override

          override :data_attributes_for
          def data_attributes_for(original, parent, object, link_content: false, link_reference: false)
            # Causes the title (returned by `object_link_title` below) to be interpreted
            # as HTML.
            super.merge!(html: true)
          end

          # Returns a String containing HTML.
          override :object_link_title
          def object_link_title(object, _matches)
            presenter = object.present(issuable_subject: project || group)

            ::LabelsHelper.label_tooltip_title_html(presenter)
          end
        end
      end
    end
  end
end
