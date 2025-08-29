<script>
import { GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { getAdaptiveStatusColor } from '~/lib/utils/color_utils';
import { __, s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import { getStatuses } from 'ee/work_items/utils';

export default {
  components: {
    GlCollapsibleListbox,
    GlIcon,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  apollo: {
    workItemTypes: {
      query: namespaceWorkItemTypesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.workspace?.workItemTypes?.nodes || [];
      },
      skip() {
        return !this.shouldFetch;
      },
      error(error) {
        Sentry.captureException(error);
        this.$emit(
          'error',
          s__('WorkItem|Something went wrong when fetching status. Please try again.'),
        );
      },
    },
  },
  data() {
    return {
      workItemTypes: [],
      selectedValue: undefined,
      searchTerm: '',
      shouldFetch: false,
    };
  },
  computed: {
    listItems() {
      let statuses = getStatuses(this.workItemTypes);
      if (this.searchTerm) {
        statuses = fuzzaldrinPlus.filter(statuses, this.searchTerm, { key: ['name'] });
      }
      return statuses.map((status) => ({
        ...status,
        value: status.id,
        text: status.name,
      }));
    },
    isLoading() {
      return this.$apollo.queries.workItemTypes.loading;
    },
    dropdownText() {
      const selected = this.listItems.find((option) => option.value === this.selectedValue);
      return selected?.text || __('Select status');
    },
  },
  methods: {
    getAdaptiveStatusColor,
    onSearch(value) {
      this.searchTerm = value;
    },
    handleReset() {
      this.selectedValue = undefined;
    },
    onDropdownHide() {
      this.onSearch('');
      this.$refs.listbox.$refs.searchBox.clearInput();
    },
  },
};
</script>

<template>
  <div>
    <input type="hidden" name="update[status]" :value="selectedValue" />
    <gl-collapsible-listbox
      id="bulk_sidebar_status_dropdown"
      ref="listbox"
      v-model="selectedValue"
      :searching="isLoading"
      :searchable="true"
      :header-text="__('Select status')"
      :reset-button-label="__('Reset')"
      :toggle-text="dropdownText"
      block
      is-check-centered
      :items="listItems"
      @shown="shouldFetch = true"
      @hidden="onDropdownHide"
      @search="onSearch"
      @reset="handleReset"
    >
      <template #list-item="{ item }">
        <div class="gl-truncate" data-testid="status-list-item">
          <gl-icon
            :name="item.iconName"
            :size="12"
            class="gl-mr-2"
            :style="{ color: getAdaptiveStatusColor(item.color) }"
          />
          <span>{{ item.text }}</span>
        </div>
      </template>
    </gl-collapsible-listbox>
  </div>
</template>
