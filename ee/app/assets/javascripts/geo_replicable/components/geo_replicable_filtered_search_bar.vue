<script>
import { s__ } from '~/locale';
import { TOKEN_TYPES } from '../constants';

export default {
  name: 'GeoReplicableFilteredSearchBar',
  i18n: {
    listboxHeaderText: s__('Geo|Select replicable type'),
    selectedReplicableType: s__('Geo|Selected replicable type'),
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
  computed: {
    activeReplicableType() {
      const activeFilter = this.activeFilters.find(
        ({ type }) => type === TOKEN_TYPES.REPLICABLE_TYPE,
      );

      return activeFilter?.value;
    },
  },
};
</script>

<template>
  <div class="row-content-block">
    <div class="gl-flex gl-grow gl-flex-col gl-border-t-0 sm:gl-flex sm:gl-flex-row sm:gl-gap-3">
      <span data-testid="active-filters">{{ activeFilters }}</span>
      <span data-testid="active-replicable-type">{{ activeReplicableType }}</span>
    </div>
  </div>
</template>
