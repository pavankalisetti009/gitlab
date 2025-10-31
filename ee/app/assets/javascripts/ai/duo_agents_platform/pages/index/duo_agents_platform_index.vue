<script>
import { GlExperimentBadge, GlSkeletonLoader, GlFilteredSearchToken } from '@gitlab/ui';
import emptyStateIllustrationPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import {
  FILTERED_SEARCH_TERM,
  OPERATORS_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import { __, s__ } from '~/locale';
import AgentFlowList from '../../components/common/agent_flow_list.vue';
import {
  AGENT_PLATFORM_INDEX_COMPONENT_NAME,
  DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES,
} from '../../constants';

export default {
  name: AGENT_PLATFORM_INDEX_COMPONENT_NAME,
  components: {
    AgentFlowList,
    FilteredSearchBar,
    GlExperimentBadge,
    GlSkeletonLoader,
    PageHeading,
  },
  inject: {
    isSidePanelView: {
      default: false,
    },
  },
  props: {
    hasInitialWorkflows: {
      required: true,
      type: Boolean,
    },
    initialSort: {
      required: true,
      type: String,
    },
    isLoadingWorkflows: {
      required: true,
      type: Boolean,
    },
    workflows: {
      required: true,
      type: Array,
    },
    workflowsPageInfo: {
      required: true,
      type: Object,
    },
  },
  data() {
    return {
      currentFilters: [],
      currentSort: this.initialSort,
      paginationVariables: {},
      filterVariables: {},
    };
  },
  computed: {
    showEmptyState() {
      return !this.hasInitialWorkflows;
    },
    processedFiltersForGraphQL() {
      const FILTER_TYPE_MAP = {
        'flow-name': 'type',
        'flow-status-group': 'statusGroup',
        [FILTERED_SEARCH_TERM]: 'search',
      };

      return this.currentFilters
        .filter((filter) => filter.value?.data && FILTER_TYPE_MAP[filter.type])
        .reduce((acc, filter) => {
          const mappedProperty = FILTER_TYPE_MAP[filter.type];
          acc[mappedProperty] = filter.value.data;
          return acc;
        }, {});
    },
  },
  methods: {
    handleNextPage() {
      const paginationVars = {
        before: null,
        after: this.workflowsPageInfo.endCursor,
        first: 20,
        last: null,
      };
      this.handlePagination(paginationVars);
    },
    handlePrevPage() {
      const paginationVars = {
        after: null,
        before: this.workflowsPageInfo.startCursor,
        first: null,
        last: 20,
      };
      this.handlePagination(paginationVars);
    },
    handlePagination(paginationVars) {
      this.paginationVariables = paginationVars;
      this.emitVariables();
    },
    resetPagination() {
      this.handlePagination(DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES);
    },
    handleSort(sortBy) {
      this.currentSort = sortBy;
      this.resetPagination();
      this.emitVariables();
    },
    handleFilter(filters) {
      this.currentFilters = filters;
      this.refetchWithFilters(this.processedFiltersForGraphQL);
    },
    refetchWithFilters(filters) {
      this.filterVariables = filters;
      this.resetPagination();
      this.emitVariables();
    },
    emitVariables() {
      this.$emit('query-variables-updated', {
        sort: this.currentSort,
        pagination: this.paginationVariables,
        filters: this.filterVariables,
      });
    },
  },
  emptyStateIllustrationPath,
  availableSortOptions: [
    {
      id: 1,
      title: __('Created date'),
      sortDirection: {
        descending: 'CREATED_DESC',
        ascending: 'CREATED_ASC',
      },
    },
    {
      id: 2,
      title: __('Updated date'),
      sortDirection: {
        descending: 'UPDATED_DESC',
        ascending: 'UPDATED_ASC',
      },
    },
  ],
  tokens: [
    {
      type: 'flow-name',
      title: s__('DuoAgentsPlatform|Flow Name'),
      icon: 'flow-ai',
      token: GlFilteredSearchToken,
      operators: OPERATORS_IS,
      unique: true,
      options: [
        { value: 'software_development', title: s__('DuoAgentsPlatform|Software Development') },
        { value: 'convert_to_gitlab_ci', title: s__('DuoAgentsPlatform|Convert to gitlab ci') },
      ],
    },
    {
      type: 'flow-status-group',
      title: __('Status'),
      icon: 'status',
      token: GlFilteredSearchToken,
      operators: OPERATORS_IS,
      unique: true,
      options: [
        { value: 'ACTIVE', title: __('Active') },
        { value: 'PAUSED', title: __('Paused') },
        { value: 'AWAITING_INPUT', title: __('Awaiting input') },
        { value: 'COMPLETED', title: __('Completed') },
        { value: 'FAILED', title: __('Failed') },
        { value: 'CANCELED', title: __('Canceled') },
      ],
    },
  ],
};
</script>
<template>
  <div class="gl-min-h-full gl-flex-wrap gl-justify-center">
    <page-heading v-if="!isSidePanelView">
      <template #heading>
        <div class="gl-flex">
          <span>{{ s__('DuoAgentsPlatform|Sessions') }}</span>
          <gl-experiment-badge type="beta" class="gl-self-center" />
        </div>
      </template>
    </page-heading>
    <filtered-search-bar
      v-if="hasInitialWorkflows"
      namespace="duo-agents-platform"
      :tokens="$options.tokens"
      :search-input-placeholder="s__('DuoAgentsPlatform|Search for a session')"
      :sort-options="$options.availableSortOptions"
      :initial-sort-by="initialSort"
      :initial-sort="initialSort"
      recent-searches-storage-key="agent-sessions"
      sync-filter-and-sort
      terms-as-tokens
      class="gl-grow gl-border-t-0 gl-p-4"
      data-testid="agent-sessions-search-container"
      @onFilter="handleFilter"
      @onSort="handleSort"
    />
    <div
      v-if="isLoadingWorkflows"
      class="gl-flex gl-w-full gl-flex-col gl-gap-5 gl-p-5"
      data-testid="loading-container"
    >
      <gl-skeleton-loader :lines="2" :width="300" />
      <gl-skeleton-loader :lines="2" :width="300" />
      <gl-skeleton-loader :lines="2" :width="300" />
    </div>
    <agent-flow-list
      v-else
      :show-project-info="isSidePanelView"
      :show-empty-state="showEmptyState"
      :initial-sort="initialSort"
      :workflows="workflows"
      :workflows-page-info="workflowsPageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
  </div>
</template>
