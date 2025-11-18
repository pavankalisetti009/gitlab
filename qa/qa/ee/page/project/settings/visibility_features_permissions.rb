# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          module VisibilityFeaturesPermissions
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                view 'ee/app/assets/javascripts/pages/projects/shared/permissions/' \
                  'secrets_manager/secrets_manager_settings.vue' do
                  element 'secret-manager'
                  element 'secret-manager-toggle'
                end
              end
            end

            def has_secrets_manager_section?
              has_element?('secret-manager') ||
                has_text?('Secrets Manager')
            end

            def secrets_manager_enabled?
              if has_element?('secret-manager-toggle')
                within_element('secret-manager-toggle') do
                  toggle = find('[role="switch"]', wait: 5)
                  toggle['aria-checked'] == 'true'
                end
              else
                false
              end
            rescue Capybara::ElementNotFound
              false
            end

            def enable_secrets_manager
              toggle_secrets_manager unless secrets_manager_enabled?
            end

            # Secret Permissions Methods
            def has_secrets_manager_permissions_section?
              has_text?('Secrets manager user permissions')
            end

            def add_user_permission(username:, scopes:)
              add_permission(name: username, scopes: scopes, type: 'USER')
            end

            def has_user_permission?(username:, scopes:)
              has_permission?(name: username, scopes: scopes)
            end

            def delete_user_permission(username:)
              delete_permission(name: username, tab: 'Users')
            end

            def add_role_permission(role_name:, scopes:)
              add_permission(name: role_name.upcase, scopes: scopes, type: 'ROLE')
            end

            def has_role_permission?(role_name:, scopes:)
              has_permission?(name: role_name, scopes: scopes, tab: 'Roles')
            end

            def delete_role_permission(role_name:)
              delete_permission(name: role_name, tab: 'Roles')
            end

            def add_group_permission(group_id:, scopes:)
              add_permission(name: group_id, scopes: scopes, type: 'GROUP')
            end

            def has_group_permission?(group_name:, scopes:)
              has_permission?(name: group_name, scopes: scopes, tab: 'Group')
            end

            def delete_group_permission(group_name:)
              delete_permission(name: group_name, tab: 'Group')
            end

            def enable_specific_permission(scope_name:)
              execute_script(<<~JS)
                const labels = document.querySelectorAll('label[class*="custom-control-label"]');
                const readLabel = Array.from(labels).find(label => label.textContent.trim().startsWith("#{scope_name.capitalize}"));
                if (readLabel) readLabel.click();
              JS
            end

            def click_save_button
              page.execute_script("document.querySelector('.js-modal-action-primary').click()")
            end

            def alert_text
              page.execute_script("return document.querySelector('.gl-alert-body')?.textContent")
            end

            def has_add_permission_button?
              has_button?('Add')
            end

            def has_owner_permissions_in_roles_tab?
              click_on('Roles')
              within('tbody') do
                has_css?('tr', text: 'Owner') && has_text?('Create, Update, Delete, Read')
              end
            end

            private

            def toggle_secrets_manager
              raise 'Secrets manager toggle not found' unless has_element?('secret-manager-toggle')

              within_element('secret-manager-toggle') do
                toggle = find('[role="switch"]', wait: 5)
                toggle.click unless toggle[:disabled] == 'true' || toggle[:class].include?('gl-toggle-disabled')
              end
            end

            def add_permission(name:, scopes:, type:)
              # Click the "Add" dropdown button in the secrets manager permissions section
              within_element('crud-actions') do
                click_button('Add')
              end

              case type
              when 'GROUP'
                click_element('listbox-item-GROUP')
              when 'USER'
                click_element('listbox-item-USER')
              else
                click_element('listbox-item-ROLE')
              end
              page.execute_script("document.querySelector('#secret-permission-principal button').click()")
              wait_for_requests
              page.execute_script(
                "document.querySelector(\"[data-testid='listbox-item-#{name}']\").click()"
              )
              wait_for_requests

              enable_specific_permission(scope_name: 'read') unless scopes.include?('read')

              # Select permission scopes using execute_script for more reliable selection
              scopes.each do |scope|
                scope_capitalized = scope.capitalize
                page.execute_script("
                  const labels = document.querySelectorAll('label[class*=\"custom-control-label\"]');
                  for (const label of labels) {
                    if (label.textContent.trim().startsWith('#{scope_capitalized}')) {
                      const checkboxId = label.getAttribute('for');
                      const checkbox = document.getElementById(checkboxId);
                      if (checkbox && !checkbox.checked) {
                        checkbox.click();
                      }
                      break;
                    }
                  }
                ")
              end

              enable_specific_permission(scope_name: 'read') unless scopes.include?('read')

              click_save_button
              wait_for_requests
            end

            def has_permission?(name:, scopes:, tab: nil)
              find('[role="tab"]', text: tab).click if tab.present?
              begin
                row = find('tr', text: name)
              rescue StandardError
                return false
              end

              scopes.each do |scope|
                return false unless row.has_text?(scope.capitalize)
              end

              true
            end

            def delete_permission(name:, tab: nil)
              find('[role="tab"]', text: tab).click if tab.present?
              row = find('tr', text: name)
              within(row) do
                delete_button = find('[data-testid="remove-icon"]', wait: 2).ancestor('button')
                if delete_button
                  delete_button.click
                  page.execute_script(
                    "document.querySelector('.js-modal-action-primary').click()"
                  )
                end
              end
              wait_for_requests
            end
          end
        end
      end
    end
  end
end
