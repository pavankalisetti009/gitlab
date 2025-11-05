<script>
import { debounce } from 'lodash';
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
import { queryToObject, setUrlParams, updateHistory, visitUrl } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import { getModels, putBulkModelAction } from 'ee/api/data_management_api';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import DataManagementItem from 'ee/admin/data_management/components/data_management_item.vue';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
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
    modelClass: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isLoading: true,
      modelItems: [],
      filters: [],
    };
  },
  computed: {
    hasItems() {
      return Boolean(this.modelItems.length);
    },
    hasFilters() {
      return Boolean(this.filters.length);
    },
    emptyState() {
      return {
        title: sprintf(s__('Geo|No %{itemTitle} exist'), {
          itemTitle: this.modelClass.titlePlural.toLowerCase(),
        }),
        description: s__(
          'Geo|If you believe this is an error, see the %{linkStart}Geo troubleshooting%{linkEnd} documentation.',
        ),
        helpLink: GEO_TROUBLESHOOTING_LINK,
        hasFilters: this.hasFilters,
      };
    },
    modelTitle() {
      return this.modelClass.titlePlural.toLowerCase();
    },
  },
  created() {
    this.initializeFilters();
    this.fetchModelList();
  },
  methods: {
    initializeFilters() {
      const filters = [];
      const { checksum_state: checksumState, identifiers } = queryToObject(
        window.location.search || '',
        { gatherArrays: true },
      );

      if (identifiers) {
        filters.push(identifiers.join(' '));
      }

      if (isValidFilter(checksumState, CHECKSUM_STATES_ARRAY)) {
        filters.push({ type: TOKEN_TYPES.CHECKSUM_STATE, value: { data: checksumState } });
      }

      this.filters = filters;
    },
    fetchModelList: debounce(async function fetchModelList() {
      this.isLoading = true;

      try {
        const { query } = processFilters(this.filters);
        const { data } = await getModels(this.modelClass.name, query);

        this.modelItems = convertObjectPropsToCamelCase(data, { deep: true });
      } catch (error) {
        this.handleFetchError(error);
      } finally {
        this.isLoading = false;
      }
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    async handleBulkAction({ action, successMessage, errorMessage }) {
      try {
        await putBulkModelAction(this.modelClass.name, action);

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
    handleListboxChange(model) {
      this.updateUrl({ model, redirect: true });
    },
    handleSearch(filters) {
      this.filters = filters;
      this.updateUrl({ model: this.modelClass.name, redirect: false });
    },
    updateUrl({ model, redirect }) {
      const filters = [{ type: TOKEN_TYPES.MODEL, value: model }, ...this.filters];
      const { query, url } = processFilters(filters);

      const urlWithParams = setUrlParams(query, {
        url: url.href,
        clearParams: true,
        railsArraySyntax: true,
      });

      if (redirect) {
        visitUrl(urlWithParams);
      } else {
        updateHistory({ url: urlWithParams });
        this.fetchModelList();
      }
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
      :active-listbox-item="modelClass.name"
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
        :model-name="modelClass.name"
        :initial-item="item"
      />
    </geo-list>
  </div>
</template>
