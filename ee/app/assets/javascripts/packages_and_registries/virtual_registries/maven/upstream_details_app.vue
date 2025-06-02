<script>
import { GlFilteredSearch, GlLoadingIcon } from '@gitlab/ui';
import {
  getMavenUpstreamCacheEntries,
  deleteMavenUpstreamCacheEntry,
} from 'ee/api/virtual_registries_api';
import { createAlert } from '~/alert';
import { setUrlParams, updateHistory, queryToObject } from '~/lib/utils/url_utility';
import UpstreamDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/upstream_details_header.vue';
import CacheEntriesTable from 'ee/packages_and_registries/virtual_registries/components/cache_entries_table.vue';
import { s__ } from '~/locale';

export default {
  name: 'MavenUpstreamDetailsApp',
  components: {
    CacheEntriesTable,
    GlFilteredSearch,
    GlLoadingIcon,
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
      loading: true,
      urlParams: {},
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
  },
  mounted() {
    const queryStringObject = queryToObject(window.location.search);

    if (queryStringObject.search) {
      this.urlParams = queryStringObject;
    }

    this.fetchCacheEntries();
  },
  methods: {
    async fetchCacheEntries() {
      this.loading = true;

      try {
        const response = await getMavenUpstreamCacheEntries({
          id: this.upstream.id,
          params: { ...this.urlParams },
        });
        this.cacheEntries = response.data;
      } catch (error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to fetch cache entries.'),
          error,
          captureError: true,
        });
      } finally {
        this.loading = false;
      }
    },
    async handleDeleteCacheEntry({ id }) {
      this.loading = true;

      try {
        await deleteMavenUpstreamCacheEntry({
          id,
        });
        this.fetchCacheEntries();
      } catch (error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to delete cache entry.'),
          error,
          captureError: true,
        });
      } finally {
        this.loading = false;
      }
    },
    async searchCacheEntries(filters) {
      this.loading = true;

      try {
        const searchTerm = filters[0];

        const response = await getMavenUpstreamCacheEntries({
          id: this.upstream.id,
          params: { search: searchTerm },
        });

        this.cacheEntries = response.data;

        this.urlParams = { search: searchTerm };
        updateHistory({
          url: setUrlParams({ search: searchTerm }, window.location.href, true),
        });
      } catch (error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to search cache entries.'),
          error,
          captureError: true,
        });
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<template>
  <gl-loading-icon v-if="loading" size="lg" class="gl-mt-5" />

  <div v-else>
    <upstream-details-header :upstream="upstream" />

    <div class="row-content-block gl-flex gl-flex-col gl-gap-3 md:gl-flex-row">
      <gl-filtered-search
        class="gl-min-w-0 gl-grow"
        :placeholder="__('Filter results')"
        :search-text-option-label="__('Search for this text')"
        :value="filteredSearchValue"
        terms-as-tokens
        @submit="searchCacheEntries"
      />
    </div>

    <cache-entries-table :cache-entries="cacheEntries" @delete="handleDeleteCacheEntry" />
  </div>
</template>
