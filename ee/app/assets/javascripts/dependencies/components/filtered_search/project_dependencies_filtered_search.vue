<script>
import { GlFilteredSearch } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { __, s__ } from '~/locale';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import ComponentToken from './tokens/component_token.vue';

export default {
  components: {
    GlFilteredSearch,
  },
  data() {
    return {
      value: [],
      currentFilterParams: null,
    };
  },
  computed: {
    ...mapState(['currentList']),
    tokens() {
      return [
        {
          type: 'component_names',
          title: __('Component'),
          multiSelect: true,
          unique: true,
          token: ComponentToken,
          operators: OPERATORS_IS,
        },
      ];
    },
  },
  methods: {
    ...mapActions('allDependencies', ['setSearchFilterParameters']),
  },
  i18n: {
    searchInputPlaceholder: s__('Dependencies|Search or filter dependencies...'),
  },
  filteredSearchId: 'project-level-filtered-search',
};
</script>

<template>
  <div>
    <gl-filtered-search
      :id="$options.filteredSearchId"
      :placeholder="$options.i18n.searchInputPlaceholder"
      :available-tokens="tokens"
      terms-as-tokens
      @input="setSearchFilterParameters"
    />
  </div>
</template>
