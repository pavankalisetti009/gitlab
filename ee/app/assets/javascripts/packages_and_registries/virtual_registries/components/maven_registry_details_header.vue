<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlTooltipDirective,
} from '@gitlab/ui';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { sprintf, s__, __ } from '~/locale';

export default {
  name: 'MavenRegistryDetailsHeader',
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    MetadataItem,
    TitleArea,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
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
  data() {
    return {
      isDropdownVisible: false,
    };
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry && this.registryEditPath;
    },
    copyText() {
      return sprintf(s__('VirtualRegistry|Copy virtual registry ID: %{id}'), {
        id: this.registry.id,
      });
    },
    moreActionsTooltip() {
      return this.isDropdownVisible ? '' : this.$options.i18n.moreActionsLabel;
    },
  },
  methods: {
    showDropdown() {
      this.isDropdownVisible = true;
    },
    hideDropdown() {
      this.isDropdownVisible = false;
    },
    onCopy() {
      this.$toast.show(s__('VirtualRegistry|Virtual registry ID copied to clipboard.'));
    },
  },
  i18n: {
    moreActionsLabel: __('More actions'),
  },
};
</script>

<template>
  <title-area :title="registry.name">
    <template #right-actions>
      <gl-button v-if="canEdit" :href="registryEditPath">
        {{ __('Edit') }}
      </gl-button>
      <gl-disclosure-dropdown
        v-if="registry.id"
        v-gl-tooltip
        category="tertiary"
        icon="ellipsis_v"
        :title="moreActionsTooltip"
        no-caret
        :toggle-text="$options.i18n.moreActionsLabel"
        text-sr-only
        @shown="showDropdown"
        @hidden="hideDropdown"
      >
        <gl-disclosure-dropdown-item :data-clipboard-text="registry.id" @action="onCopy">
          <template #list-item>
            {{ copyText }}
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown>
    </template>
    <template #metadata-registry-type>
      <metadata-item icon="infrastructure-registry" :text="s__('VirtualRegistry|Maven')" />
    </template>
    <template #sub-header>
      <div>{{ s__('VirtualRegistry|You can add up to 20 upstreams per registry.') }}</div>
    </template>
    <p data-testid="description">{{ registry.description }}</p>
  </title-area>
</template>
