<script>
import { GlFilteredSearch, GlPagination } from '@gitlab/ui';
import {
  getMavenUpstreamCacheEntries,
  deleteMavenUpstreamCacheEntry,
} from 'ee/api/virtual_registries_api';
import { createAlert } from '~/alert';
import { setUrlParams, updateHistory, queryToObject } from '~/lib/utils/url_utility';
import UpstreamDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/upstream_details_header.vue';
import CacheEntriesTable from 'ee/packages_and_registries/virtual_registries/components/cache_entries_table.vue';
import { s__ } from '~/locale';

const PAGE_SIZE = 20;
const INITIAL_PAGE = 1;

export default {
  name: 'MavenUpstreamDetailsApp',
  perPage: PAGE_SIZE,
  components: {
    CacheEntriesTable,
    GlFilteredSearch,
    GlPagination,
    UpstreamDetailsHeader,
  },
  inject: {
    upstream: {
      default: {},
    },
  },
  data() {
    return {
      cacheEntries: [],
      cacheEntriesCount: 0,
      cacheEntriesCountLoading: false,
      cacheEntriesLoading: false,
      urlParams: {},
      page: INITIAL_PAGE,
    };
  },
  computed: {
    filteredSearchValue() {
      return [
        {
          type: 'filtered-search-term',
          value: { data: this.urlParams.search || '' },
        },
      ];
    },
    showPagination() {
      return this.cacheEntriesCount > this.$options.perPage;
    },
  },
  created() {
    const queryStringObject = queryToObject(window.location.search);

    // Extract both search and page from URL
    this.urlParams = queryStringObject.search ? { search: queryStringObject.search } : {};
    this.page = parseInt(queryStringObject.page, 10) || INITIAL_PAGE;

    this.fetchCacheEntries(this.page, { isInitialLoad: true });
  },
  methods: {
    async fetchCacheEntries(page, { isInitialLoad = false } = {}) {
      if (isInitialLoad) {
        this.cacheEntriesCountLoading = true;
      }
      this.cacheEntriesLoading = true;

      try {
        const response = await getMavenUpstreamCacheEntries({
          id: this.upstream.id,
          params: { ...this.urlParams, page, per_page: PAGE_SIZE },
        });

        this.setCacheEntries(response);

        this.updateUrl();
      } catch (error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to fetch cache entries.'),
          error,
          captureError: true,
        });
      } finally {
        if (isInitialLoad) {
          this.cacheEntriesCountLoading = false;
        }
        this.cacheEntriesLoading = false;
      }
    },
    async handleDeleteCacheEntry({ id }) {
      this.cacheEntriesCountLoading = true;
      this.cacheEntriesLoading = true;

      try {
        await deleteMavenUpstreamCacheEntry({
          id,
        });
        await this.fetchCacheEntries(this.page);
      } catch (error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to delete cache entry.'),
          error,
          captureError: true,
        });
      } finally {
        this.cacheEntriesCountLoading = false;
        this.cacheEntriesLoading = false;
      }
    },
    async searchCacheEntries(filters) {
      this.cacheEntriesCountLoading = true;
      this.cacheEntriesLoading = true;
      this.page = INITIAL_PAGE;

      try {
        const searchTerm = filters[0];

        this.urlParams = { search: searchTerm };

        const response = await getMavenUpstreamCacheEntries({
          id: this.upstream.id,
          params: { search: searchTerm, page: INITIAL_PAGE, per_page: PAGE_SIZE },
        });

        this.setCacheEntries(response);

        this.updateUrl();
      } catch (error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to search cache entries.'),
          error,
          captureError: true,
        });
      } finally {
        this.cacheEntriesCountLoading = false;
        this.cacheEntriesLoading = false;
      }
    },
    setCacheEntries({ headers, data }) {
      this.cacheEntries = data;
      this.cacheEntriesCount = Number(headers['x-total']);
    },
    handlePageChange(page) {
      this.page = page;
      this.fetchCacheEntries(page);
    },
    updateUrl() {
      const params = {};

      // Add search parameter if it exists
      if (this.urlParams.search) {
        params.search = this.urlParams.search;
      }

      params.page = this.page;

      if (Object.keys(params).length > 0) {
        updateHistory({
          url: setUrlParams(params, { url: window.location.href, clearParams: true }),
        });
      }
    },
  },
};
</script>

<template>
  <div>
    <upstream-details-header
      :upstream="upstream"
      :loading="cacheEntriesCountLoading"
      :cache-entries-count="cacheEntriesCount"
    />

    <div class="gl-border-t gl-flex gl-flex-col gl-gap-3 gl-bg-subtle gl-p-5 @md/panel:gl-flex-row">
      <gl-filtered-search
        class="gl-min-w-0 gl-grow"
        :placeholder="__('Filter results')"
        :search-text-option-label="__('Search for this text')"
        :value="filteredSearchValue"
        terms-as-tokens
        @submit="searchCacheEntries"
      />
    </div>

    <cache-entries-table
      :cache-entries="cacheEntries"
      :loading="cacheEntriesLoading"
      @delete="handleDeleteCacheEntry"
    />

    <gl-pagination
      v-if="showPagination"
      :value="page"
      :per-page="$options.perPage"
      :total-items="cacheEntriesCount"
      align="center"
      class="gl-mt-5"
      @input="handlePageChange"
    />
  </div>
</template>
