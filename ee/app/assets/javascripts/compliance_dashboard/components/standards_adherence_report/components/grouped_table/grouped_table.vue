<script>
import { s__ } from '~/locale';

import TablePart from './table_part.vue';

export default {
  components: {
    TablePart,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
  },
  computed: {
    fields() {
      const columnWidth = 'gl-md-max-w-10 gl-whitespace-nowrap';
      const column = (options) => ({
        key: options.key,
        label: this.$options.i18n.tableHeaders[options.key],
        sortable: false,
        thClass: columnWidth,
        tdClass: columnWidth,
      });

      return [
        column({ key: 'status' }),
        column({ key: 'requirement' }),
        column({ key: 'framework' }),
        column({ key: 'project' }),
        column({ key: 'lastScanned' }),
        column({ key: 'fixSuggestions' }),
      ];
    },
    tableItems() {
      if (this.items.length > 1 || this.items[0].group !== null) {
        // eslint-disable-next-line @gitlab/require-i18n-strings
        throw new Error('Grouped table does not support multiple groups');
      }

      return this.items[0].children;
    },
  },
  i18n: {
    tableHeaders: {
      status: s__('ComplianceStandardsAdherence|Status'),
      requirement: s__('ComplianceStandardsAdherence|Requirement'),
      framework: s__('ComplianceStandardsAdherence|Framework'),
      project: s__('ComplianceStandardsAdherence|Project'),
      lastScanned: s__('ComplianceStandardsAdherence|Last scanned'),
      fixSuggestions: s__('ComplianceStandardsAdherence|Fix suggestions'),
    },
    viewDetails: s__('ComplianceStandardsAdherence|View details'),
  },
};
</script>

<template>
  <div>
    <table-part
      :items="tableItems"
      :fields="fields"
      @row-selected="$emit('row-selected', $event)"
    />
  </div>
</template>
