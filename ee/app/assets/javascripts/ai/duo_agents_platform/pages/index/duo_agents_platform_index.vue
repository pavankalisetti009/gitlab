<script>
import { GlAlert, GlExperimentBadge, GlSkeletonLoader, GlFilteredSearchToken } from '@gitlab/ui';
import emptyStateIllustrationPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import {
  OPERATORS_IS,
  FILTERED_SEARCH_TERM,
} from '~/vue_shared/components/filtered_search_bar/constants';
import { __, s__ } from '~/locale';
import AgentFlowList from '../../components/common/agent_flow_list.vue';
import { AGENT_PLATFORM_INDEX_COMPONENT_NAME } from '../../constants';

export default {
  name: AGENT_PLATFORM_INDEX_COMPONENT_NAME,
  components: {
    AgentFlowList,
    FilteredSearchBar,
    GlAlert,
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
      showAlert: false,
      currentFilters: [],
    };
  },
  computed: {
    showEmptyState() {
      return !this.hasInitialWorkflows;
    },
    processedFiltersForGraphQL() {
      const processedFilters = {};

      this.currentFilters.forEach((filter) => {
        if (filter.type === 'flow-name' && filter.value?.data) {
          processedFilters.type = filter.value.data;
        }
      });

      return processedFilters;
    },
  },
  methods: {
    handleNextPage() {
      this.$emit('update-pagination', {
        before: null,
        after: this.workflowsPageInfo.endCursor,
        first: 20,
        last: null,
      });
    },
    handlePrevPage() {
      this.$emit('update-pagination', {
        after: null,
        before: this.workflowsPageInfo.startCursor,
        first: null,
        last: 20,
      });
    },
    handleSort(sortBy) {
      this.$emit('update-sort', sortBy);
    },
    handleFilter(filters) {
      if (this.hasUnsupportedTextSearch(filters)) {
        this.showAlert = true;
        this.currentFilters = []; // Clear the filters
        this.$forceUpdate(); // Force re-render to clear the search input
        return;
      }

      this.showAlert = false;
      this.currentFilters = filters;
      this.refetchWithFilters(this.processedFiltersForGraphQL);
    },
    hasUnsupportedTextSearch(filters) {
      return filters.some((filter) => filter.type === FILTERED_SEARCH_TERM && filter.value?.data);
    },
    refetchWithFilters(processedFilters) {
      this.$emit('update-filters', processedFilters);
    },
    dismissAlert() {
      this.showAlert = false;
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
    <gl-alert
      v-if="showAlert"
      variant="warning"
      dismissible
      class="gl-mx-4 gl-mt-2"
      @dismiss="dismissAlert"
    >
      {{
        s__(
          'DuoAgentsPlatform|Raw text search is not currently supported. Please use the available search tokens.',
        )
      }}
    </gl-alert>
    <filtered-search-bar
      v-if="hasInitialWorkflows"
      namespace="duo-agents-platform"
      :tokens="$options.tokens"
      :search-input-placeholder="s__('DuoAgentsPlatform|Search for a session')"
      :sort-options="$options.availableSortOptions"
      :initial-sort-by="initialSort"
      :initial-sort="initialSort"
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
