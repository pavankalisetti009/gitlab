# frozen_string_literal: true

module EE
  module Banzai
    module Filter
      module References
        module LabelReferenceFilter
          extend ::Gitlab::Utils::Override

          override :data_attributes_for
          def data_attributes_for(original, parent, object, link_content: false, link_reference: false)
            return super unless object.scoped_label?

            # Enabling HTML tooltips for scoped labels here.
            super.merge!(html: true)
          end
        end
      end
    end
  end
end
