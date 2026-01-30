# frozen_string_literal: true

module VirtualRegistryHelper
  def registry_types(group)
    {
      maven: {
        new_page_path: new_group_virtual_registries_maven_registry_path(group),
        landing_page_path: group_virtual_registries_maven_registries_and_upstreams_path(group),
        image_path: 'illustrations/logos/maven.svg',
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

  def maven_registries_and_upstreams_data(group)
    maven_upstream_template_links(group).merge({
      fullPath: group.full_path,
      editRegistryPathTemplate: edit_group_virtual_registries_maven_registry_path(group, ':id'),
      showRegistryPathTemplate: group_virtual_registries_maven_registry_path(group, ':id')
    }).to_json
  end

  def max_registries_count_exceeded?(group, registry_type)
    return max_maven_registries_count_exceeded?(group) if registry_type == :maven

    false
  end

  def max_maven_registries_count_exceeded?(group)
    ::VirtualRegistries.registries_count_for(group, registry_type: 'maven') >=
      VirtualRegistries::Packages::Maven::Registry::MAX_REGISTRY_COUNT
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
      mavenCentralUrl: maven_central_url,
      upstream: maven_upstream_attributes(maven_upstream),
      upstreamsPath: group_virtual_registries_maven_registries_and_upstreams_path(maven_upstream.group,
        { tab: 'upstreams' }),
      upstreamPath: group_virtual_registries_maven_upstream_path(maven_upstream.group, maven_upstream)
    }.to_json
  end

  def maven_upstream_data(upstream)
    {
      initialUpstream: {
        id: upstream.id,
        name: upstream.name,
        url: upstream.url,
        description: upstream.description
      },
      editUpstreamPath: edit_group_virtual_registries_maven_upstream_path(upstream.group, upstream)
    }.to_json
  end

  def maven_registry_data(group, maven_registry)
    maven_upstream_template_links(group).merge({
      groupPath: group.full_path,
      registry: {
        id: maven_registry.id,
        name: maven_registry.name,
        description: maven_registry.description
      },
      registryEditPath: edit_group_virtual_registries_maven_registry_path(group, maven_registry),
      mavenCentralUrl: maven_central_url
    }).to_json
  end

  def container_template_data(group)
    {
      full_path: group.full_path,
      base_path: group_virtual_registries_container_path(group),
      max_registries_count: VirtualRegistries::Container::Registry::MAX_REGISTRY_COUNT
    }
  end

  private

  def maven_upstream_attributes(maven_upstream)
    {
      id: maven_upstream.id,
      name: maven_upstream.name,
      url: maven_upstream.url,
      description: maven_upstream.description,
      username: maven_upstream.username,
      cacheValidityHours: maven_upstream.cache_validity_hours,
      metadataCacheValidityHours: maven_upstream.metadata_cache_validity_hours
    }
  end

  def maven_central_url
    ::VirtualRegistries::Packages::Maven::Upstream::MAVEN_CENTRAL_URL
  end

  def maven_upstream_template_links(group)
    {
      editUpstreamPathTemplate: edit_group_virtual_registries_maven_upstream_path(group, ':id'),
      showUpstreamPathTemplate: group_virtual_registries_maven_upstream_path(group, ':id')
    }
  end
end
