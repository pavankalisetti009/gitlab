<script>
import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { __ } from '~/locale';
import NameCell from './name_cell.vue';
import VulnerabilityCell from './vulnerability_cell.vue';
import ToolCoverageCell from './tool_coverage_cell.vue';
import ActionCell from './action_cell.vue';

const SKELETON_ROW_COUNT = 3;

export default {
  components: {
    GlTableLite,
    GlSkeletonLoader,
    NameCell,
    VulnerabilityCell,
    ToolCoverageCell,
    ActionCell,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    displayItems() {
      return this.isLoading && this.items.length === 0
        ? Array(SKELETON_ROW_COUNT).fill({})
        : this.items;
    },
  },
  fields: [
    { key: 'name', label: __('Name') },
    { key: 'vulnerabilities', label: __('Vulnerabilities') },
    { key: 'toolCoverage', label: __('Tool Coverage') },
    { key: 'actions', label: '' },
  ],
};
</script>

<template>
  <gl-table-lite :items="displayItems" :fields="$options.fields" hover>
    <template #cell(name)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :width="200" :height="40" preserve-aspect-ratio="none">
        <rect x="0" y="10" width="24" height="24" rx="4" />
        <rect x="34" y="10" width="100" height="10" rx="3" />
        <rect x="34" y="25" width="200" height="10" rx="3" />
      </gl-skeleton-loader>
      <name-cell v-else :item="item" />
    </template>

    <template #cell(vulnerabilities)="{ item, index }">
      <gl-skeleton-loader v-if="isLoading" :height="40">
        <rect x="0" y="10" width="250" height="10" rx="3" />
        <rect x="0" y="25" width="20" height="14" rx="4" />
      </gl-skeleton-loader>
      <vulnerability-cell v-else :item="item" :index="index" />
    </template>

    <template #cell(toolCoverage)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :width="300" :height="30" preserve-aspect-ratio="none">
        <rect x="0" y="6" width="32" height="20" rx="10" />
        <rect x="38" y="6" width="32" height="20" rx="10" />
        <rect x="76" y="6" width="32" height="20" rx="10" />
        <rect x="114" y="6" width="32" height="20" rx="10" />
        <rect x="152" y="6" width="32" height="20" rx="10" />
        <rect x="190" y="6" width="32" height="20" rx="10" />
      </gl-skeleton-loader>
      <tool-coverage-cell v-else :item="item" />
    </template>

    <template #cell(actions)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :width="32" :height="18">
        <rect x="0" y="5" width="12" height="12" rx="2" />
      </gl-skeleton-loader>
      <action-cell v-else :item="item" />
    </template>
  </gl-table-lite>
</template>
