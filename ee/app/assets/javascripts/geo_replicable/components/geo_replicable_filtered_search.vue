<script>
import { GlFilteredSearch } from '@gitlab/ui';
import { __ } from '~/locale';
import {
  TOKEN_TYPES,
  FILTERED_SEARCH_TOKEN_DEFINITIONS,
  REPLICATION_STATUS_STATES_ARRAY,
} from '../constants';

export default {
  name: 'GeoReplicableFilteredSearch',
  i18n: {
    searchPlaceholder: __('Search or filter results…'),
  },
  components: {
    GlFilteredSearch,
  },
  props: {
    activeFilters: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    tokens() {
      return FILTERED_SEARCH_TOKEN_DEFINITIONS.map((def) => {
        let options = [];

        if (def.type === TOKEN_TYPES.REPLICATION_STATUS) {
          options = REPLICATION_STATUS_STATES_ARRAY;
        }

        return { ...def, options };
      });
    },
  },
  methods: {
    handleSubmit(val) {
      this.$emit('search', val);
    },
  },
};
</script>

<template>
  <gl-filtered-search
    :value="activeFilters"
    :available-tokens="tokens"
    terms-as-tokens
    :placeholder="$options.i18n.searchPlaceholder"
    @submit="handleSubmit"
  />
</template>
