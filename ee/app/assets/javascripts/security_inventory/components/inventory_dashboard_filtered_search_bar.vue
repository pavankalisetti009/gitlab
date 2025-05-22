<script>
import { __ } from '~/locale';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { UPDATED_ASC, UPDATED_DESC } from '~/issues/list/constants';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import { queryToObject } from '~/lib/utils/url_utility';

const sortOptions = [
  {
    id: 1,
    title: __('Updated date'),
    sortDirection: {
      descending: UPDATED_DESC,
      ascending: UPDATED_ASC,
    },
  },
];

export default {
  name: 'InventoryDashboardFilteredSearchBar',
  components: {
    FilteredSearch,
  },
  props: {
    initialFilters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    namespace: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      initialSortBy: 'updated_at_desc',
      filterParams: {},
    };
  },
  computed: {
    searchTokens() {
      return [];
    },
    initialFilterValue() {
      if (this.initialFilters.search) {
        return [this.initialFilters.search];
      }
      const searchParam = queryToObject(window.location.search).search;
      return searchParam ? [searchParam] : [];
    },
  },
  methods: {
    onFilter(filters = []) {
      const filterParams = {};
      const plainText = [];

      filters.forEach((filter) => {
        if (!filter.value.data) return;

        if (filter.type === FILTERED_SEARCH_TERM) {
          plainText.push(filter.value.data);
        }
      });

      if (plainText.length) {
        filterParams.search = plainText.join(' ');
      }

      this.filterParams = { ...filterParams };
      this.$emit('filterSubgroupsAndProjects', this.filterParams);
    },
  },
  sortOptions,
};
</script>

<template>
  <filtered-search
    v-bind="$attrs"
    :namespace="namespace"
    :sort-options="$options.sortOptions"
    :initial-filter-value="initialFilterValue"
    :tokens="searchTokens"
    :initial-sort-by="initialSortBy"
    :search-input-placeholder="s__('SecurityInventoryFilter|Search projects…')"
    :search-text-option-label="s__('SecurityInventoryFilter|Search for project name')"
    terms-as-tokens
    @onFilter="onFilter"
  />
</template>
