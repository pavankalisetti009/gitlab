<script>
import { GlButton } from '@gitlab/ui';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';

export default {
  name: 'MavenRegistryDetailsApp',
  components: {
    GlButton,
    MetadataItem,
    TitleArea,
    CrudComponent,
  },
  inject: {
    mavenVirtualRegistryEditPath: {
      default: '',
    },
  },
  props: {
    registry: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    upstreams: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
};
</script>

<template>
  <div>
    <title-area :title="registry.name">
      <template #metadata-registry-type>
        <metadata-item icon="infrastructure-registry" :text="s__('VirtualRegistry|Maven')" />
      </template>
      <p data-testid="description">{{ registry.description }}</p>
      <template #right-actions>
        <gl-button :href="mavenVirtualRegistryEditPath">
          {{ __('Edit') }}
        </gl-button>
      </template>
    </title-area>
    <crud-component
      :title="s__('VirtualRegistry|Upstreams')"
      icon="infrastructure-registry"
      :count="upstreams.count"
    >
      <template #default>
        <ul v-if="upstreams.count">
          <li v-for="upstream in upstreams.nodes" :key="upstream.id">
            {{ upstream.name }}
          </li>
        </ul>
        <p v-else class="gl-text-subtle">
          {{ s__('VirtualRegistry|No upstreams yet') }}
        </p>
      </template>
    </crud-component>
  </div>
</template>
