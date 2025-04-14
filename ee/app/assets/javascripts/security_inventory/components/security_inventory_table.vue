<script>
import { GlTableLite } from '@gitlab/ui';
import { __ } from '~/locale';
import NameCell from './name_cell.vue';
import VulnerabilityCell from './vulnerability_cell.vue';
import ToolCoverageCell from './tool_coverage_cell.vue';
import ActionCell from './action_cell.vue';

export default {
  components: {
    GlTableLite,
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
  <gl-table-lite :items="items" :fields="$options.fields" hover>
    <template #cell(name)="{ item }">
      <name-cell v-if="item" :item="item" />
    </template>

    <template #cell(vulnerabilities)="{ item, index }">
      <vulnerability-cell v-if="item" :item="item" :index="index" />
    </template>

    <template #cell(toolCoverage)="{ item }">
      <tool-coverage-cell v-if="item" :item="item" />
    </template>

    <template #cell(actions)="{ item }">
      <action-cell v-if="item" :item="item" />
    </template>
  </gl-table-lite>
</template>
