<script>
import { GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import GeoListBulkActions from 'ee/geo_shared/list/components/geo_list_bulk_actions.vue';
import GeoListFilteredSearchBar from 'ee/geo_shared/list/components/geo_list_filtered_search_bar.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { visitUrl, pathSegments, queryToObject, setUrlParams } from '~/lib/utils/url_utility';
import {
  isValidFilter,
  getReplicationStatusFilter,
  getReplicableTypeFilter,
  processFilters,
} from '../filters';
import { REPLICATION_STATUS_STATES_ARRAY, TOKEN_TYPES, BULK_ACTIONS } from '../constants';
import GeoReplicable from './geo_replicable.vue';
import GeoReplicableEmptyState from './geo_replicable_empty_state.vue';
import GeoReplicableFilterBar from './geo_replicable_filter_bar.vue';
import GeoFeedbackBanner from './geo_feedback_banner.vue';

export default {
  name: 'GeoReplicableApp',
  components: {
    GlLoadingIcon,
    GeoReplicableFilterBar,
    GeoListFilteredSearchBar,
    GeoReplicable,
    GeoReplicableEmptyState,
    GeoListBulkActions,
    GeoFeedbackBanner,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    geoReplicableEmptySvgPath: {
      type: String,
      required: true,
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
  },
  created() {
    if (this.glFeatures.geoReplicablesFilteredListView) {
      this.getFiltersFromQuery();
    }

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
    onListboxChange(val) {
      this.onSearch([getReplicableTypeFilter(val), ...this.activeFilteredSearchFilters]);
    },
    onSearch(filters) {
      const { query, url } = processFilters(filters);

      visitUrl(setUrlParams(query, url.href, true));
    },
    onBulkAction(action) {
      this.initiateAllReplicableAction({ action });
    },
  },
  BULK_ACTIONS,
};
</script>

<template>
  <article class="geo-replicable-container">
    <geo-feedback-banner />
    <geo-replicable-filter-bar v-if="!glFeatures.geoReplicablesFilteredListView" />
    <template v-else>
      <geo-list-filtered-search-bar
        :listbox-header-text="s__('Geo|Select replicable type')"
        :active-listbox-item="activeReplicableType"
        :active-filtered-search-filters="activeFilteredSearchFilters"
        @listboxChange="onListboxChange"
        @search="onSearch"
      />
      <geo-list-bulk-actions
        v-if="hasReplicableItems"
        :bulk-actions="$options.BULK_ACTIONS"
        class="gl-my-5 gl-flex gl-justify-end"
        @bulkAction="onBulkAction"
      />
    </template>

    <gl-loading-icon v-if="isLoading" size="xl" />
    <template v-else>
      <geo-replicable v-if="hasReplicableItems" />
      <geo-replicable-empty-state
        v-else
        :geo-replicable-empty-svg-path="geoReplicableEmptySvgPath"
      />
    </template>
  </article>
</template>
