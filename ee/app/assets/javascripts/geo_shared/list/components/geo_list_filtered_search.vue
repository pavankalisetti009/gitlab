<script>
import { GlFilteredSearch } from '@gitlab/ui';
import { isEqual } from 'lodash';
import { __ } from '~/locale';

export default {
  i18n: {
    searchPlaceholder: __('Search or filter results…'),
  },
  components: {
    GlFilteredSearch,
  },
  inject: {
    filteredSearchTokens: {
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
    filteredSearchOptionLabel: {
      type: String,
      required: false,
      default: '',
    },
  },
  methods: {
    handleSubmit(val) {
      if (isEqual(this.activeFilters, val)) return;

      this.$emit('search', val);
    },
  },
};
</script>

<template>
  <gl-filtered-search
    :value="activeFilters"
    :available-tokens="filteredSearchTokens"
    :search-text-option-label="filteredSearchOptionLabel"
    terms-as-tokens
    :placeholder="$options.i18n.searchPlaceholder"
    @submit="handleSubmit"
  />
</template>
