<script>
import { GlSearchBoxByType, GlCollapsibleListbox, GlModalDirective } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { s__ } from '~/locale';
import { DEFAULT_SEARCH_DELAY, FILTER_STATES, FILTER_OPTIONS } from '../constants';
import GeoReplicableBulkActions from './geo_replicable_bulk_actions.vue';

export default {
  name: 'GeoReplicableFilterBar',
  i18n: {
    searchPlaceholder: s__('Geo|Filter by name'),
  },
  components: {
    GlSearchBoxByType,
    GlCollapsibleListbox,
    GeoReplicableBulkActions,
  },
  directives: {
    GlModalDirective,
  },
  computed: {
    ...mapState(['statusFilter', 'searchFilter', 'replicableItems', 'titlePlural']),
    search: {
      get() {
        return this.searchFilter;
      },
      set(val) {
        this.setSearch(val);
        this.fetchReplicableItems();
      },
    },
    dropdownItems() {
      return FILTER_OPTIONS.map((option) => {
        if (option.value === FILTER_STATES.ALL.value) {
          return { ...option, text: `${option.label} ${this.titlePlural}` };
        }

        return { ...option, text: option.label };
      });
    },
    hasReplicableItems() {
      return this.replicableItems.length > 0;
    },
    showBulkActions() {
      return this.hasReplicableItems;
    },
    showSearch() {
      // To be implemented via https://gitlab.com/gitlab-org/gitlab/-/issues/411982
      return false;
    },
  },
  methods: {
    ...mapActions(['setStatusFilter', 'setSearch', 'fetchReplicableItems']),
    filterChange(filter) {
      this.setStatusFilter(filter);
      this.fetchReplicableItems();
    },
  },
  debounce: DEFAULT_SEARCH_DELAY,
};
</script>

<template>
  <nav class="gl-bg-strong gl-p-5">
    <div class="geo-replicable-filter-grid gl-grid gl-gap-3">
      <div class="gl-flex gl-flex-col gl-items-center sm:gl-flex-row">
        <gl-collapsible-listbox
          class="gl-w-1/2"
          :items="dropdownItems"
          :selected="statusFilter"
          block
          @select="filterChange"
        />
        <gl-search-box-by-type
          v-if="showSearch"
          v-model="search"
          :debounce="$options.debounce"
          class="gl-ml-0 gl-mt-3 gl-w-full sm:gl-ml-3 sm:gl-mt-0"
          :placeholder="$options.i18n.searchPlaceholder"
        />
      </div>
      <geo-replicable-bulk-actions v-if="showBulkActions" class="gl-ml-auto" />
    </div>
  </nav>
</template>
