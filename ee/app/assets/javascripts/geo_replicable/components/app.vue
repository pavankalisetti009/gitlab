<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import { sprintf, s__ } from '~/locale';
import { visitUrl, pathSegments, queryToObject, setUrlParams } from '~/lib/utils/url_utility';
import {
  isValidFilter,
  getReplicationStatusFilter,
  getReplicableTypeFilter,
  processFilters,
} from '../filters';
import {
  REPLICATION_STATUS_STATES_ARRAY,
  TOKEN_TYPES,
  BULK_ACTIONS,
  GEO_TROUBLESHOOTING_LINK,
} from '../constants';
import GeoReplicable from './geo_replicable.vue';
import GeoFeedbackBanner from './geo_feedback_banner.vue';

export default {
  name: 'GeoReplicableApp',
  components: {
    GeoListTopBar,
    GeoReplicable,
    GeoFeedbackBanner,
    GeoList,
  },
  inject: {
    itemTitle: {
      default: '',
    },
    siteName: {
      default: '',
    },
  },
  data() {
    return {
      activeFilters: [],
    };
  },
  computed: {
    ...mapState(['isLoading', 'replicableItems']),
    hasReplicableItems() {
      return this.replicableItems.length > 0;
    },
    activeReplicableType() {
      const activeFilter = this.activeFilters.find(
        ({ type }) => type === TOKEN_TYPES.REPLICABLE_TYPE,
      );

      return activeFilter?.value;
    },
    activeFilteredSearchFilters() {
      return this.activeFilters.filter(({ type }) => type !== TOKEN_TYPES.REPLICABLE_TYPE);
    },
    emptyStateHasFilters() {
      return Boolean(this.activeFilteredSearchFilters.length);
    },
    emptyState() {
      return {
        title: sprintf(s__('Geo|There are no %{itemTitle} to show'), { itemTitle: this.itemTitle }),
        description: s__(
          'Geo|No %{itemTitle} were found. If you believe this may be an error, please refer to the %{linkStart}Geo Troubleshooting%{linkEnd} documentation for more information.',
        ),
        itemTitle: this.itemTitle,
        helpLink: GEO_TROUBLESHOOTING_LINK,
        hasFilters: this.emptyStateHasFilters,
      };
    },
    pageHeadingTitle() {
      return sprintf(s__('Geo|Geo Replication - %{siteName}'), { siteName: this.siteName });
    },
  },
  created() {
    this.getFiltersFromQuery();
    this.fetchReplicableItems();
  },
  methods: {
    ...mapActions(['fetchReplicableItems', 'setStatusFilter', 'initiateAllReplicableAction']),
    getFiltersFromQuery() {
      const filters = [];
      const url = new URL(window.location.href);
      const segments = pathSegments(url);
      const { replication_status: replicationStatus } = queryToObject(window.location.search || '');

      if (isValidFilter(replicationStatus, REPLICATION_STATUS_STATES_ARRAY)) {
        filters.push(getReplicationStatusFilter(replicationStatus));
        this.setStatusFilter(replicationStatus);
      }

      this.activeFilters = [getReplicableTypeFilter(segments.pop()), ...filters];
    },
    handleListboxChange(val) {
      this.handleSearch([getReplicableTypeFilter(val), ...this.activeFilteredSearchFilters]);
    },
    handleSearch(filters) {
      const { query, url } = processFilters(filters);

      visitUrl(setUrlParams(query, url.href, true));
    },
    handleBulkAction(action) {
      this.initiateAllReplicableAction({ action });
    },
  },
  BULK_ACTIONS,
};
</script>

<template>
  <article class="geo-replicable-container">
    <geo-feedback-banner />
    <geo-list-top-bar
      :page-heading-title="pageHeadingTitle"
      :page-heading-description="
        s__(
          'Geo|Review replication status, and resynchronize and reverify items with the primary site.',
        )
      "
      :listbox-header-text="s__('Geo|Select replicable type')"
      :active-listbox-item="activeReplicableType"
      :active-filtered-search-filters="activeFilteredSearchFilters"
      :show-actions="hasReplicableItems"
      :bulk-actions="$options.BULK_ACTIONS"
      @listboxChange="handleListboxChange"
      @search="handleSearch"
      @bulkAction="handleBulkAction"
    />

    <geo-list :is-loading="isLoading" :has-items="hasReplicableItems" :empty-state="emptyState">
      <geo-replicable />
    </geo-list>
  </article>
</template>
