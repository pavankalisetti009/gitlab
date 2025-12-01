<script>
import { computed } from 'vue';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import { sprintf, s__ } from '~/locale';
import {
  BULK_ACTIONS,
  DEFAULT_SORT,
  GEO_TROUBLESHOOTING_LINK,
} from 'ee/admin/data_management/constants';
import { extractFiltersFromQuery, processFilters } from 'ee/admin/data_management/filters';
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
      activeModelName: this.initialModelName,
      modelItems: [],
      filters: [],
      pageInfo: {},
      isLoading: true,
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
    routerParams() {
      const { query, params } = this.$route;
      return convertObjectPropsToCamelCase({ ...query, ...params });
    },
    query() {
      const filterQuery = processFilters(this.filters);
      return {
        ...filterQuery,
        order_by: this.pageInfo.sort.value,
        sort: this.pageInfo.sort.direction,
      };
    },
    queryWithPagination() {
      return { ...this.query, pagination: 'keyset' };
    },
  },
  watch: {
    $route: {
      handler() {
        this.initializeModel();
        this.initializePageInfo();
        this.initializeFilters();
        this.fetchModelList();
      },
      immediate: true,
    },
  },
  methods: {
    initializePageInfo() {
      this.pageInfo = {
        sort: {
          value: this.routerParams.orderBy || DEFAULT_SORT.value,
          direction: this.routerParams.sort || DEFAULT_SORT.direction,
        },
      };
    },
    initializeFilters() {
      this.filters = extractFiltersFromQuery(this.routerParams);
    },
    initializeModel() {
      this.activeModelName = this.routerParams.modelName || this.initialModelName;
    },
    async fetchModelList() {
      this.isLoading = true;

      try {
        const { data } = await getModels(this.activeModelName, this.queryWithPagination);

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
    handleListboxChange(modelName) {
      const params = { modelName };
      this.$router.push({ params, query: this.query });
    },
    handleSearch(filters) {
      this.filters = filters;
      this.$router.push({ params: this.$route.params, query: this.query });
    },
    handleSort(sort) {
      this.pageInfo = { ...this.pageInfo, sort };
      this.$router.push({ params: this.$route.params, query: this.query });
    },
  },
  BULK_ACTIONS,
};
</script>

<template>
  <section>
    <geo-list-top-bar
      :active-filtered-search-filters="filters"
      :page-heading-title="__('Data management')"
      :page-heading-description="
        s__('Geo|Review stored data and data health within your instance.')
      "
      :filtered-search-option-label="__('Search by ID')"
      :active-listbox-item="activeModelName"
      :active-sort="pageInfo.sort"
      :bulk-actions="$options.BULK_ACTIONS"
      :show-actions="hasItems"
      @listboxChange="handleListboxChange"
      @search="handleSearch"
      @sort="handleSort"
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
  </section>
</template>
