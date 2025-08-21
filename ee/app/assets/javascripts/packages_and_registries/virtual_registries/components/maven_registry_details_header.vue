<script>
import { GlButton } from '@gitlab/ui';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';

export default {
  name: 'MavenRegistryDetailsHeader',
  components: {
    GlButton,
    MetadataItem,
    TitleArea,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    registryEditPath: {
      default: '',
    },
    registry: {
      default: {},
    },
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry && this.registryEditPath;
    },
  },
};
</script>

<template>
  <title-area :title="registry.name">
    <template v-if="canEdit" #right-actions>
      <gl-button :href="registryEditPath">
        {{ __('Edit') }}
      </gl-button>
    </template>
    <template #metadata-registry-type>
      <metadata-item icon="infrastructure-registry" :text="s__('VirtualRegistry|Maven')" />
    </template>
    <p data-testid="description">{{ registry.description }}</p>
  </title-area>
</template>
