<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__ } from '~/locale';
import SearchSuggestion from '../components/search_suggestion.vue';

export default {
  validValues: ['ACTIVE', 'INACTIVE', 'UNKNOWN'],
  transformFilters: (filters) => {
    return { validity: Array.isArray(filters) ? filters[0] : filters };
  },
  transformQueryParams: (params) => {
    return Array.isArray(params) ? params[0] : params;
  },
  components: {
    GlFilteredSearchToken,
    SearchSuggestion,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      selectedValidityCheck: this.value.data?.[0] || 'UNKNOWN',
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedValidityCheck,
      };
    },
    queryStringValue() {
      return this.selectedValidityCheck ? [this.selectedValidityCheck] : [];
    },
    toggleText() {
      return getSelectedOptionsText({
        selected: [this.selectedValidityCheck],
        options: this.$options.items,
        placeholder: this.$options.i18n.label,
      });
    },
  },
  methods: {
    toggleSelected(selectedValue) {
      this.selectedValidityCheck = selectedValue;
    },
  },
  i18n: {
    label: s__('SecurityReports|Validity Check'),
  },
  items: [
    {
      value: 'ACTIVE',
      text: s__('SecurityReports|Active secret'),
    },
    {
      value: 'INACTIVE',
      text: s__('SecurityReports|Inactive secret'),
    },
    {
      value: 'UNKNOWN',
      text: s__('SecurityReports|Possibly active secret'),
    },
  ],
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :value="tokenValue"
    v-on="$listeners"
    @select="toggleSelected"
  >
    <template #view>
      <span data-testid="validity-check-token-placeholder">{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <search-suggestion
        v-for="item in $options.items"
        :key="item.value"
        :value="item.value"
        :text="item.text"
        :selected="item.value === selectedValidityCheck"
        :data-testid="`suggestion-${item.value}`"
      />
    </template>
  </gl-filtered-search-token>
</template>
