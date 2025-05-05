# frozen_string_literal: true

module VirtualRegistryHelper
  def registry_types(group, registry_types_with_counts)
    {
      maven: {
        new_page_path: new_group_virtual_registries_maven_registry_path(group),
        landing_page_path: group_virtual_registries_maven_registries_path(group),
        image_path: 'illustrations/logos/maven.svg',
        count: registry_types_with_counts[:maven],
        type_name: s_('VirtualRegistry|Maven')
      }
    }
  end

  def can_create_virtual_registry?(group)
    can?(current_user, :create_virtual_registry, group.virtual_registry_policy_subject)
  end
end
