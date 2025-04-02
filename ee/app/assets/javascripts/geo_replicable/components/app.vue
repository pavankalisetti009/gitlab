<script>
import { GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { visitUrl, pathSegments, queryToObject, setUrlParams } from '~/lib/utils/url_utility';
import {
  isValidFilter,
  getReplicationStatusFilter,
  getReplicableTypeFilter,
  processFilters,
} from '../filters';
import { REPLICATION_STATUS_STATES_ARRAY } from '../constants';
import GeoReplicable from './geo_replicable.vue';
import GeoReplicableEmptyState from './geo_replicable_empty_state.vue';
import GeoReplicableFilterBar from './geo_replicable_filter_bar.vue';
import GeoReplicableFilteredSearchBar from './geo_replicable_filtered_search_bar.vue';

export default {
  name: 'GeoReplicableApp',
  components: {
    GlLoadingIcon,
    GeoReplicableFilterBar,
    GeoReplicableFilteredSearchBar,
    GeoReplicable,
    GeoReplicableEmptyState,
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
  },
  created() {
    if (this.glFeatures.geoReplicablesFilteredListView) {
      this.getFiltersFromQuery();
    }

    this.fetchReplicableItems();
  },
  methods: {
    ...mapActions(['fetchReplicableItems', 'setStatusFilter']),
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
    onSearch(filters) {
      const { query, url } = processFilters(filters);

      visitUrl(setUrlParams(query, url.href, true));
    },
  },
};
</script>

<template>
  <article class="geo-replicable-container">
    <geo-replicable-filter-bar v-if="!glFeatures.geoReplicablesFilteredListView" />
    <geo-replicable-filtered-search-bar v-else :active-filters="activeFilters" @search="onSearch" />

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
