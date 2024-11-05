<script>
import { GlLoadingIcon, GlTable } from '@gitlab/ui';
import { s__, __ } from '~/locale';

import EditSection from './edit_section.vue';

export default {
  name: 'FrameworkRequirements',
  components: {
    EditSection,
    GlLoadingIcon,
    GlTable,
  },
  props: {
    requirements: {
      type: Array,
      required: true,
    },
  },
  tableFields: [
    {
      key: 'name',
      label: s__('ComplianceFrameworks|Requirement name'),
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-white',
    },
    {
      key: 'description',
      label: s__('ComplianceFrameworks|Description'),
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-white',
    },
    {
      key: 'controls',
      label: s__('ComplianceFrameworks|Controls'),
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-white',
    },
  ],
  i18n: {
    requirements: s__('ComplianceFrameworks|Requirements'),
    requirementsDescription: s__(
      'ComplianceFrameworks|Configure requirements set forth by laws, regulations, and industry standards.',
    ),
    actionEdit: __('Edit'),
    actionDelete: __('Remove'),
    newRequirement: s__('ComplianceFrameworks|New requirement'),
  },
};
</script>
<template>
  <edit-section
    :title="$options.i18n.requirements"
    :description="$options.i18n.requirementsDescription"
    :items-count="requirements.length"
  >
    <gl-table
      v-if="requirements.length"
      ref="requirementsTable"
      class="requirements-table gl-mb-6"
      :items="requirements"
      :fields="$options.tableFields"
      responsive
      stacked="md"
      hover
      select-mode="single"
      selected-variant="primary"
    >
      <template #cell(name)="{ item }">
        {{ item.name }}
      </template>
      <template #cell(description)="{ item }">
        {{ item.description }}
      </template>
      <template #cell(controls)="{ item }">
        <ul
          v-if="
            item.controlExpression &&
            item.controlExpression.nodes &&
            item.controlExpression.nodes.length
          "
          class="gl-m-0 gl-p-0"
        >
          <li v-for="control in item.controlExpression.nodes" :key="control.id">
            {{ control.name }}
          </li>
        </ul>
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" />
      </template>
    </gl-table>
  </edit-section>
</template>
