<script>
import { GlIcon, GlLink, GlTable, GlTableLite, GlKeysetPagination } from '@gitlab/ui';
import { __ } from '~/locale';
import { isExternal } from '~/lib/utils/url_utility';
import { formatVisualizationValue } from '../utils';

const DEFAULT_PAGE_SIZE = 20;

export default {
  name: 'DataTable',
  components: {
    GlIcon,
    GlLink,
    GlTable,
    GlTableLite,
    GlKeysetPagination,
    AssigneeAvatars: () => import('./assignee_avatars.vue'),
    CalculateSum: () => import('./calculate_sum.vue'),
    DiffLineChanges: () => import('./diff_line_changes.vue'),
    CalculatePercent: () => import('./calculate_percent.vue'),
    FormatTime: () => import('./format_time.vue'),
    FormatTimeRange: () => import('./format_time_range.vue'),
    MergeRequestLink: () => import('./merge_request_link.vue'),
    MilestoneLink: () => import('./milestone_link.vue'),
    ChangePercentageIndicator: () => import('./change_percentage_indicator.vue'),
    MetricLabel: () => import('./metric_label.vue'),
    TrendLine: () => import('./trend_line.vue'),
    UserLink: () => import('./user_link.vue'),
  },
  props: {
    data: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    query: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    tableComponent() {
      const hasSorting = this.options.fields?.some(({ sortable }) => Boolean(sortable));
      return hasSorting ? GlTable : GlTableLite;
    },
    nodes() {
      return this.data.nodes || [];
    },
    pageInfo() {
      return this.data.pageInfo || {};
    },
    derivedFields() {
      // NOTE: we derive the field names from the keys in the first row of data
      // unless a custom field config is passed in the visualization options
      if (this.nodes.length < 1) {
        return null;
      }

      return Object.keys(this.nodes[0]).map((key) => ({
        key,
        tdClass: 'gl-truncate gl-max-w-0',
      }));
    },
    sanitizedOptions() {
      const { responsive, fixed, stacked, fields, refetchOnSort } = this.options;
      return {
        responsive: responsive ?? true,
        fixed: fixed ?? false,
        stacked: stacked ?? false,
        refetchOnSort: refetchOnSort ?? false,
        fields: fields || this.derivedFields,
      };
    },
    showPaginationControls() {
      return Boolean(this.pageInfo.hasPreviousPage || this.pageInfo.hasNextPage);
    },
  },
  methods: {
    mapComponentProps(item, props) {
      if (!props) return {};
      return Object.entries(props).reduce(
        (acc, [newKey, oldKey]) => ({ ...acc, [newKey]: item[oldKey] }),
        {},
      );
    },
    isLink(value) {
      return Boolean(value?.text && value?.href);
    },
    isExternalLink(href) {
      return isExternal(href);
    },
    formatVisualizationValue,
    nextPage() {
      const { first, last, endCursor } = this.pageInfo;
      this.$emit('updateQuery', {
        pagination: {
          first: first ?? last ?? DEFAULT_PAGE_SIZE,
          endCursor,
        },
      });
    },
    prevPage() {
      const { first, last, startCursor } = this.pageInfo;
      this.$emit('updateQuery', {
        pagination: {
          last: last ?? first ?? DEFAULT_PAGE_SIZE,
          startCursor,
        },
      });
    },
    onSortingChanged({ sortBy, sortDesc }) {
      if (this.sanitizedOptions.refetchOnSort) {
        this.$emit('updateQuery', { sortBy, sortDesc });
      }
    },
  },
  i18n: {
    externalLink: __('external link'),
  },
};
</script>

<template>
  <div>
    <component
      :is="tableComponent"
      :fields="sanitizedOptions.fields"
      :responsive="sanitizedOptions.responsive"
      :fixed="sanitizedOptions.fixed"
      :stacked="sanitizedOptions.stacked"
      :no-local-sorting="sanitizedOptions.refetchOnSort"
      :items="nodes"
      :sort-by="query.sortBy"
      :sort-desc="query.sortDesc"
      hover
      class="gl-mt-4"
      @sort-changed="onSortingChanged"
    >
      <template #cell()="{ item, value, field }">
        <component
          :is="field.component"
          v-if="field.component"
          v-bind="{ ...value, ...mapComponentProps(item, field.componentProps) }"
        />
        <gl-link v-else-if="isLink(value)" :href="value.href"
          >{{ formatVisualizationValue(value.text) }}
          <gl-icon
            v-if="isExternalLink(value.href)"
            name="external-link"
            :size="12"
            :aria-label="$options.i18n.externalLink"
            class="gl-ml-1"
          />
        </gl-link>
        <template v-else>
          {{ formatVisualizationValue(value) }}
        </template>
      </template>
    </component>
    <gl-keyset-pagination
      v-if="showPaginationControls"
      class="gl-m-3 gl-flex gl-items-center gl-justify-center"
      v-bind="pageInfo"
      @prev="prevPage"
      @next="nextPage"
    />
  </div>
</template>
