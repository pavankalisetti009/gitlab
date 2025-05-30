<script>
import { GlFilteredSearch, GlLoadingIcon } from '@gitlab/ui';
import {
  getMavenUpstreamCacheEntries,
  deleteMavenUpstreamCacheEntry,
} from 'ee/api/virtual_registries_api';
import { createAlert } from '~/alert';
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
      search: [],
      loading: true,
    };
  },
  mounted() {
    this.fetchCacheEntries();
  },
  methods: {
    async fetchCacheEntries() {
      this.loading = true;

      try {
        const response = await getMavenUpstreamCacheEntries({
          id: this.upstream.id,
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
  },
};
</script>

<template>
  <gl-loading-icon v-if="loading" size="lg" class="gl-mt-5" />
  <div v-else>
    <upstream-details-header :upstream="upstream" />

    <div class="row-content-block gl-flex gl-flex-col gl-gap-3 md:gl-flex-row">
      <gl-filtered-search
        v-model="search"
        class="gl-min-w-0 gl-grow"
        :placeholder="__('Filter results')"
        :search-text-option-label="__('Search for this text')"
        terms-as-tokens
      />
    </div>

    <cache-entries-table :cache-entries="cacheEntries" @delete="handleDeleteCacheEntry" />
  </div>
</template>
