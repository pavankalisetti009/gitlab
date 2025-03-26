<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getReplicableTypeFilter } from '../filters';
import { TOKEN_TYPES } from '../constants';

export default {
  name: 'GeoReplicableFilteredSearchBar',
  i18n: {
    listboxHeaderText: s__('Geo|Select replicable type'),
    selectedReplicableType: s__('Geo|Selected replicable type'),
  },
  components: {
    GlCollapsibleListbox,
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
        this.$emit('search', [getReplicableTypeFilter(val)]);
      },
    },
  },
  methods: {
    onReplicableTypeSearch(search) {
      this.replicableTypeSearch = search;
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
    </div>
  </div>
</template>
