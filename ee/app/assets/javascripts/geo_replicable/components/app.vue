<script>
import { GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { visitUrl, pathSegments, setUrlParams } from '~/lib/utils/url_utility';
import { getReplicableTypeFilter, processFilters } from '../filters';
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
    ...mapActions(['fetchReplicableItems']),
    getFiltersFromQuery() {
      const url = new URL(window.location.href);
      const segments = pathSegments(url);

      this.activeFilters = [getReplicableTypeFilter(segments.pop())];
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
