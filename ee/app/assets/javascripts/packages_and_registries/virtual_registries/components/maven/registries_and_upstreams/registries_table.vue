<script>
import { GlButton, GlLink, GlTableLite, GlTooltipDirective } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { s__, sprintf } from '~/locale';

export default {
  components: {
    GlButton,
    GlLink,
    GlTableLite,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  inject: ['editRegistryPathTemplate', 'showRegistryPathTemplate'],
  props: {
    registries: {
      type: Array,
      required: true,
    },
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry;
    },
    fields() {
      return [
        {
          key: 'name',
          label: s__('VirtualRegistry|Registry'),
          thClass: '!gl-border-t-0',
          tdClass: '@sm/panel:gl-max-w-0 !gl-py-3',
        },
        {
          key: 'updated',
          label: s__('VirtualRegistry|Last updated'),
          thClass: 'gl-w-20 !gl-border-t-0',
          tdClass: '!gl-py-3',
        },
        {
          key: 'actions',
          hide: !this.canEdit,
          label: s__('VirtualRegistry|Actions'),
          thClass: 'gl-w-6 gl-text-right !gl-border-t-0',
          tdClass: 'gl-text-right !gl-py-3',
        },
      ];
    },
  },
  methods: {
    getEditRegistryLabel(name) {
      return sprintf(s__('VirtualRegistry|Edit registry %{name}'), { name });
    },
    getEditRegistryURL(registryId) {
      return this.editRegistryPathTemplate.replace(':id', getIdFromGraphQLId(registryId));
    },
    getShowRegistryURL(registryId) {
      return this.showRegistryPathTemplate.replace(':id', getIdFromGraphQLId(registryId));
    },
  },
};
</script>

<template>
  <gl-table-lite stacked="sm" :fields="fields" :items="registries" class="gl-border-t-0">
    <template #cell(name)="{ item }">
      <gl-link
        :href="getShowRegistryURL(item.id)"
        class="gl-font-bold gl-leading-24 gl-text-default"
        data-testid="registry-name"
      >
        {{ item.name }}
      </gl-link>
    </template>
    <template #cell(updated)="{ item }">
      <span class="gl-leading-24 gl-text-subtle">
        <time-ago-tooltip :time="item.updatedAt" />
      </span>
    </template>
    <template v-if="canEdit" #cell(actions)="{ item }">
      <gl-button
        v-gl-tooltip="__('Edit')"
        :aria-label="getEditRegistryLabel(item.name)"
        size="small"
        category="tertiary"
        icon="pencil"
        data-testid="edit-registry-button"
        :href="getEditRegistryURL(item.id)"
      />
    </template>
  </gl-table-lite>
</template>
