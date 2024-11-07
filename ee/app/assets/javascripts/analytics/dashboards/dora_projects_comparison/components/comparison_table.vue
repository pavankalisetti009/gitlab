<script>
import { GlTable, GlAvatarLabeled } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TABLE_FIELDS, DEFAULT_TABLE_SORT_COLUMN } from '../constants';
import MetricTableCell from './metric_table_cell.vue';

export default {
  name: 'ComparisonTable',
  TABLE_FIELDS,
  components: {
    GlTable,
    GlAvatarLabeled,
    MetricTableCell,
  },
  props: {
    projects: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      sortBy: DEFAULT_TABLE_SORT_COLUMN,
      sortDesc: true,
    };
  },
  computed: {
    noData() {
      return this.projects.length === 0;
    },
  },
  methods: {
    rowAttributes({ id }) {
      return {
        'data-testid': `project-${getIdFromGraphQLId(id)}`,
      };
    },
  },
};
</script>

<template>
  <div>
    <div v-if="noData" class="gl-text-center gl-text-secondary">
      {{ __('No data available') }}
    </div>

    <gl-table
      v-else
      :fields="$options.TABLE_FIELDS"
      :items="projects"
      :sort-by.sync="sortBy"
      :sort-desc.sync="sortDesc"
      :tbody-tr-attr="rowAttributes"
      table-class="gl-table-fixed"
    >
      <template #cell(name)="{ value, item: { avatarUrl, webUrl } }">
        <gl-avatar-labeled
          :src="avatarUrl"
          :size="24"
          :label="value"
          :label-link="webUrl"
          fallback-on-error
          shape="rect"
        />
      </template>

      <template #cell()="{ value, item: { trends }, field: { key } }">
        <metric-table-cell :value="value" :metric-type="key" :trend="trends[key]" />
      </template>
    </gl-table>
  </div>
</template>
