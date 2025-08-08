<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__ } from '~/locale';
import QuerystringSync from '../../filters/querystring_sync.vue';
import SearchSuggestion from '../components/search_suggestion.vue';
import eventHub from '../event_hub';

export default {
  validValues: ['ACTIVE', 'INACTIVE', 'UNKNOWN'],
  components: {
    QuerystringSync,
    GlFilteredSearchToken,
    SearchSuggestion,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
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
        options: this.$options.items,
        selected: [this.selectedValidityCheck],
      });
    },
  },
  methods: {
    resetSelected() {
      this.selectedValidityCheck = undefined;
      this.emitFiltersChanged();
    },
    toggleSelected(selectedValue) {
      this.selectedValidityCheck = selectedValue;
      this.emitFiltersChanged();
    },
    updateSelectedFromQS(value) {
      this.selectedValidityCheck = value?.[0];
      this.emitFiltersChanged();
    },
    emitFiltersChanged() {
      eventHub.$emit('filters-changed', { validityCheck: this.selectedValidityCheck });
    },
  },
  i18n: {
    label: s__('SecurityReports|Validity check'),
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
  <querystring-sync
    querystring-key="validityCheck"
    :value="queryStringValue"
    :valid-values="$options.validValues"
    @input="updateSelectedFromQS"
  >
    <gl-filtered-search-token
      :config="config"
      v-bind="{ ...$props, ...$attrs }"
      :value="tokenValue"
      v-on="$listeners"
      @select="toggleSelected"
      @destroy="resetSelected"
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
  </querystring-sync>
</template>
