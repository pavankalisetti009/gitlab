<script>
import { computed } from 'vue';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import { sprintf, s__ } from '~/locale';
import {
  BULK_ACTIONS,
  CHECKSUM_STATES_ARRAY,
  DEFAULT_SORT,
  GEO_TROUBLESHOOTING_LINK,
  TOKEN_TYPES,
} from 'ee/admin/data_management/constants';
import { isValidFilter, processFilters } from 'ee/admin/data_management/filters';
import { queryToObject, setUrlParams, updateHistory } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import { getModels, putBulkModelAction } from 'ee/api/data_management_api';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import DataManagementItem from 'ee/admin/data_management/components/data_management_item.vue';
import showToast from '~/vue_shared/plugins/global_toast';

export default {
  name: 'AdminDataManagementApp',
  components: {
    GeoListTopBar,
    GeoList,
    DataManagementItem,
  },
  provide() {
    return {
      itemTitle: computed(() => this.modelTitle),
    };
  },
  props: {
    initialModelName: {
      type: String,
      required: true,
    },
    modelTypes: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      isLoading: true,
      modelItems: [],
      filters: [],
      activeModelName: this.initialModelName,
    };
  },
  computed: {
    activeModel() {
      return this.modelTypes.find(({ name }) => name === this.activeModelName);
    },
    modelTitle() {
      return this.activeModel.titlePlural.toLowerCase();
    },
    hasItems() {
      return Boolean(this.modelItems.length);
    },
    hasFilters() {
      return Boolean(this.filters.length);
    },
    emptyState() {
      return {
        title: sprintf(s__('Geo|No %{itemTitle} exist'), {
          itemTitle: this.modelTitle,
        }),
        description: s__(
          'Geo|If you believe this is an error, see the %{linkStart}Geo troubleshooting%{linkEnd} documentation.',
        ),
        helpLink: GEO_TROUBLESHOOTING_LINK,
        hasFilters: this.hasFilters,
      };
    },
    queryParams() {
      return convertObjectPropsToCamelCase(
        queryToObject(window.location.search || '', { gatherArrays: true }),
      );
    },
  },
  created() {
    this.initializeModel();
    this.initializeFilters();
    this.fetchModelList();
  },
  methods: {
    initializeFilters() {
      const filters = [];
      const { checksumState, identifiers } = this.queryParams;

      if (identifiers) {
        filters.push(identifiers.join(' '));
      }

      if (isValidFilter(checksumState, CHECKSUM_STATES_ARRAY)) {
        filters.push({ type: TOKEN_TYPES.CHECKSUM_STATE, value: { data: checksumState } });
      }

      this.filters = filters;
    },
    initializeModel() {
      this.activeModelName = this.queryParams.modelName || this.initialModelName;
    },
    async fetchModelList() {
      this.isLoading = true;

      try {
        const { query } = processFilters(this.filters);
        const { data } = await getModels(this.activeModelName, query);

        this.modelItems = convertObjectPropsToCamelCase(data, { deep: true });
      } catch (error) {
        this.handleFetchError(error);
      } finally {
        this.isLoading = false;
      }
    },
    async handleBulkAction({ action, successMessage, errorMessage }) {
      try {
        await putBulkModelAction(this.activeModel.name, action);

        showToast(sprintf(successMessage, { type: this.modelTitle }));
        this.fetchModelList();
      } catch (error) {
        createAlert({
          message: sprintf(errorMessage, { type: this.modelTitle }),
          captureError: true,
          error,
        });
      }
    },
    handleFetchError(error) {
      createAlert({
        message: sprintf(
          s__('Geo|There was an error fetching %{model}. Please refresh the page and try again.'),
          { model: this.modelTitle },
        ),
        captureError: true,
        error,
      });
    },
    handleListboxChange(name) {
      this.activeModelName = name;
      this.updateUrl();
    },
    handleSearch(filters) {
      this.filters = filters;
      this.updateUrl();
    },
    updateUrl() {
      const filters = [{ type: TOKEN_TYPES.MODEL, value: this.activeModelName }, ...this.filters];
      const { query, url } = processFilters(filters);

      const urlWithParams = setUrlParams(query, {
        url: url.href,
        clearParams: true,
        railsArraySyntax: true,
      });

      updateHistory({ url: urlWithParams });
      this.fetchModelList();
    },
  },
  DEFAULT_SORT,
  BULK_ACTIONS,
};
</script>

<template>
  <div>
    <geo-list-top-bar
      :active-filtered-search-filters="filters"
      :page-heading-title="__('Data management')"
      :page-heading-description="
        s__('Geo|Review stored data and data health within your instance.')
      "
      :filtered-search-option-label="__('Search by ID')"
      :active-listbox-item="activeModelName"
      :active-sort="$options.DEFAULT_SORT"
      :bulk-actions="$options.BULK_ACTIONS"
      :show-actions="hasItems"
      @listboxChange="handleListboxChange"
      @search="handleSearch"
      @bulkAction="handleBulkAction"
    />
    <geo-list :is-loading="isLoading" :has-items="hasItems" :empty-state="emptyState">
      <data-management-item
        v-for="item in modelItems"
        :key="item.recordIdentifier"
        :model-name="activeModelName"
        :initial-item="item"
      />
    </geo-list>
  </div>
</template>
