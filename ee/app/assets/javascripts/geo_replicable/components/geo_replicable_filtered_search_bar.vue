<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getReplicableTypeFilter } from '../filters';
import { TOKEN_TYPES } from '../constants';
import GeoReplicableFilteredSearch from './geo_replicable_filtered_search.vue';

export default {
  name: 'GeoReplicableFilteredSearchBar',
  i18n: {
    listboxHeaderText: s__('Geo|Select replicable type'),
    selectedReplicableType: s__('Geo|Selected replicable type'),
  },
  components: {
    GlCollapsibleListbox,
    GeoReplicableFilteredSearch,
  },
  inject: {
    replicableTypes: {
      type: Array,
      default: [],
    },
  },
  props: {
    activeFilters: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      replicableTypeSearch: '',
    };
  },
  computed: {
    replicableTypeItems() {
      const items = this.replicableTypes.map((type) => ({
        text: type.titlePlural,
        value: type.namePlural,
      }));

      return items.filter(
        (item) =>
          item.text.toLowerCase().includes(this.replicableTypeSearch.toLowerCase()) ||
          item.value === this.activeReplicableType,
      );
    },
    activeReplicableType: {
      get() {
        const activeFilter = this.activeFilters.find(
          ({ type }) => type === TOKEN_TYPES.REPLICABLE_TYPE,
        );

        return activeFilter?.value;
      },
      set(val) {
        this.$emit('search', [getReplicableTypeFilter(val), ...this.activeSearchFilters]);
      },
    },
    activeSearchFilters() {
      return this.activeFilters.filter(({ type }) => type !== TOKEN_TYPES.REPLICABLE_TYPE);
    },
  },
  methods: {
    onReplicableTypeSearch(search) {
      this.replicableTypeSearch = search;
    },
    handleSearch(val) {
      this.$emit('search', val);
    },
  },
};
</script>

<template>
  <div class="row-content-block">
    <div class="gl-flex gl-grow gl-flex-col gl-border-t-0 sm:gl-flex sm:gl-flex-row sm:gl-gap-3">
      <label id="replicable-type-select-label" class="gl-sr-only">{{
        $options.i18n.selectedReplicableType
      }}</label>
      <gl-collapsible-listbox
        v-model="activeReplicableType"
        :items="replicableTypeItems"
        :header-text="$options.i18n.listboxHeaderText"
        searchable
        toggle-aria-labelled-by="replicable-type-select-label"
        class="gl-mb-4 sm:gl-mb-0"
        @search="onReplicableTypeSearch"
      />
      <div class="flex-grow-1 gl-flex">
        <geo-replicable-filtered-search
          :active-filters="activeSearchFilters"
          @search="handleSearch"
        />
      </div>
    </div>
  </div>
</template>
