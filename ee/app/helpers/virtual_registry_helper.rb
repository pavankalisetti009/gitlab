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

  def can_destroy_virtual_registry?(group)
    can?(current_user, :destroy_virtual_registry, group.virtual_registry_policy_subject)
  end

  def maven_registries_data(group)
    {
      fullPath: group.full_path,
      editPathTemplate: edit_group_virtual_registries_maven_registry_path(group, ':id'),
      showPathTemplate: group_virtual_registries_maven_registry_path(group, ':id')
    }.to_json
  end

  def delete_registry_modal_data(group, maven_registry)
    {
      path: group_virtual_registries_maven_registry_path(group, maven_registry),
      method: 'delete',
      modal_attributes: {
        title: s_('VirtualRegistry|Delete Maven registry'),
        size: 'sm',
        messageHtml: format(
          s_('VirtualRegistry|Are you sure you want to delete %{strongOpen}%{name}%{strongClose}?'),
          name: maven_registry.name,
          strongOpen: '<strong>'.html_safe,
          strongClose: '</strong>'.html_safe
        ),
        okVariant: 'danger',
        okTitle: _('Delete')
      }
    }
  end

  def edit_upstream_template_data(maven_upstream)
    {
      upstream: maven_upstream_attributes(maven_upstream),
      registryPath: group_virtual_registries_maven_registry_path(maven_upstream.group, maven_upstream.registry),
      upstreamPath: group_virtual_registries_maven_upstream_path(maven_upstream.group, maven_upstream)
    }.to_json
  end

  private

  def maven_upstream_attributes(maven_upstream)
    {
      id: maven_upstream.id,
      name: maven_upstream.name,
      url: maven_upstream.url,
      description: maven_upstream.description,
      username: maven_upstream.username,
      cacheValidityHours: maven_upstream.cache_validity_hours
    }
  end

  def maven_upstream_data(upstream)
    {
      upstream: {
        id: upstream.id,
        name: upstream.name,
        url: upstream.url,
        description: upstream.description,
        cacheEntriesCount: upstream.cache_entries.size
      }
    }.to_json
  end
end
