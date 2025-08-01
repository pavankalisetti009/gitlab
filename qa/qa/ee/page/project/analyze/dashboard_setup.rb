# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Analyze
          class DashboardSetup < QA::Page::Base
            view 'app/assets/javascripts/vue_shared/components/' \
                 'customizable_dashboard/gridstack_wrapper.vue' do
              element 'grid-stack-panel'
            end

            def check_total_events
              click_element 'list-item-total_events'
            end

            def check_events_over_time
              click_element 'list-item-events_over_time'
            end

            def check_visualisation(name)
              name = name.downcase.tr(' ', '_')
              click_element "list-item-#{name}"
            end
          end
        end
      end
    end
  end
end
