<script>
import { __ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import GeoListFilteredSearchBar from './geo_list_filtered_search_bar.vue';
import GeoListBulkActions from './geo_list_bulk_actions.vue';

export default {
  components: {
    PageHeading,
    GeoListFilteredSearchBar,
    GeoListBulkActions,
  },
  props: {
    pageHeadingTitle: {
      type: String,
      required: true,
    },
    pageHeadingDescription: {
      type: String,
      required: true,
    },
    listboxHeaderText: {
      type: String,
      required: false,
      default: __('Select item'),
    },
    activeListboxItem: {
      type: String,
      required: true,
    },
    activeFilteredSearchFilters: {
      type: Array,
      required: false,
      default: () => [],
    },
    showActions: {
      type: Boolean,
      required: false,
      default: false,
    },
    bulkActions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  methods: {
    handleListboxChange(val) {
      this.$emit('listboxChange', val);
    },
    handleSearch(val) {
      this.$emit('search', val);
    },
    handleBulkAction(action) {
      this.$emit('bulkAction', action);
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="pageHeadingTitle">
      <template #actions>
        <geo-list-bulk-actions
          v-if="showActions"
          :bulk-actions="bulkActions"
          @bulkAction="handleBulkAction"
        />
      </template>
      <template #description>
        {{ pageHeadingDescription }}
      </template>
    </page-heading>
    <geo-list-filtered-search-bar
      :listbox-header-text="listboxHeaderText"
      :active-listbox-item="activeListboxItem"
      :active-filtered-search-filters="activeFilteredSearchFilters"
      @listboxChange="handleListboxChange"
      @search="handleSearch"
    />
  </div>
</template>
