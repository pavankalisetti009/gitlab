<script>
import { GlFilteredSearch, GlKeysetPagination } from '@gitlab/ui';
import { deleteMavenUpstreamCacheEntry } from 'ee/api/virtual_registries_api';
import { createAlert } from '~/alert';
import { setUrlParams, updateHistory, queryToObject } from '~/lib/utils/url_utility';
import { getPageParams } from '~/packages_and_registries/shared/utils';
import getMavenUpstreamCacheEntriesCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_cache_entries_count.query.graphql';
import getMavenUpstreamCacheEntriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_cache_entries.query.graphql';
import UpstreamDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/maven/upstreams/show/header.vue';
import CacheEntriesTable from 'ee/packages_and_registries/virtual_registries/components/maven/upstreams/show/cache_entries_table.vue';
import { convertToMavenUpstreamGraphQLId } from 'ee/packages_and_registries/virtual_registries/utils';
import { s__ } from '~/locale';

const PAGE_SIZE = 20;
const INITIAL_PAGE_PARAMS = {
  first: PAGE_SIZE,
};

const QUERY_CONTEXT = {
  batchKey: 'MavenUpstreamCacheEntries',
};

export default {
  name: 'MavenUpstreamDetailsApp',
  perPage: PAGE_SIZE,
  components: {
    CacheEntriesTable,
    GlFilteredSearch,
    GlKeysetPagination,
    UpstreamDetailsHeader,
  },
  inject: {
    upstream: {
      default: {},
    },
  },
  data() {
    return {
      cacheEntriesConnection: {
        nodes: [],
        pageInfo: {},
      },
      cacheEntriesCount: 0,
      cacheEntriesCountLoadingKey: 0,
      cacheEntriesLoadingKey: 0,
      urlParams: null,
      pageParams: INITIAL_PAGE_PARAMS,
      mavenUpstreamID: convertToMavenUpstreamGraphQLId(this.upstream.id),
    };
  },
  apollo: {
    cacheEntriesCount: {
      query: getMavenUpstreamCacheEntriesCountQuery,
      context: QUERY_CONTEXT,
      loadingKey: 'cacheEntriesCountLoadingKey',
      skip() {
        return this.urlParamsIsNotSet;
      },
      variables() {
        return {
          id: this.mavenUpstreamID,
          search: this.urlParams.search,
        };
      },
      update: (data) => data.virtualRegistriesPackagesMavenUpstream?.cacheEntries?.count ?? 0,
      error(error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to fetch cache entries count.'),
          error,
          captureError: true,
        });
      },
    },
    cacheEntriesConnection: {
      query: getMavenUpstreamCacheEntriesQuery,
      loadingKey: 'cacheEntriesLoadingKey',
      context: QUERY_CONTEXT,
      skip() {
        return this.urlParamsIsNotSet;
      },
      variables() {
        return this.queryVariables;
      },
      update: (data) =>
        data.virtualRegistriesPackagesMavenUpstream?.cacheEntries ?? {
          nodes: [],
          pageInfo: {},
        },
      error(error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to fetch cache entries.'),
          error,
          captureError: true,
        });
      },
    },
  },
  computed: {
    cacheEntriesLoading() {
      return Boolean(this.cacheEntriesLoadingKey);
    },
    cacheEntriesCountLoading() {
      return Boolean(this.cacheEntriesCountLoadingKey);
    },
    cacheEntries() {
      return this.cacheEntriesConnection.nodes;
    },
    filteredSearchValue() {
      return [
        {
          type: 'filtered-search-term',
          value: { data: this.urlParams.search || '' },
        },
      ];
    },
    pageInfo() {
      return this.cacheEntriesConnection.pageInfo;
    },
    queryVariables() {
      return {
        id: this.mavenUpstreamID,
        ...this.urlParams,
        ...this.pageParams,
      };
    },
    urlParamsIsNotSet() {
      return this.urlParams === null;
    },
  },
  created() {
    const queryStringObject = queryToObject(window.location.search);

    // Extract both search and page from URL
    if (queryStringObject.after) {
      this.pageParams = this.buildPageParams({ after: queryStringObject.after });
    } else if (queryStringObject.before) {
      this.pageParams = this.buildPageParams({ before: queryStringObject.before });
    }
    this.urlParams = queryStringObject.search ? { search: queryStringObject.search } : {};
  },
  methods: {
    async handleDeleteCacheEntry({ id }) {
      try {
        await deleteMavenUpstreamCacheEntry({
          id,
        });
        this.pageParams = INITIAL_PAGE_PARAMS;
        this.$apollo.queries.cacheEntriesCount.refetch();
        this.$apollo.queries.cacheEntriesConnection.refetch();
      } catch (error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to delete cache entry.'),
          error,
          captureError: true,
        });
      }
    },
    async searchCacheEntries(filters) {
      const searchTerm = filters[0];
      this.urlParams = { search: searchTerm };
      this.updateUrlAndPageParams(this.urlParams, INITIAL_PAGE_PARAMS);
    },
    buildPageParams(pageInfo) {
      return getPageParams(pageInfo, PAGE_SIZE);
    },
    handleNextPage() {
      const urlParams = { after: this.pageInfo.endCursor };
      const pageParams = this.buildPageParams(urlParams);

      this.updateUrlAndPageParams(urlParams, pageParams);
    },
    handlePreviousPage() {
      const urlParams = { before: this.pageInfo.startCursor };
      const pageParams = this.buildPageParams(urlParams);

      this.updateUrlAndPageParams(urlParams, pageParams);
    },
    updateUrlAndPageParams(params, pageParams) {
      this.pageParams = pageParams;

      const updatedParams = {
        ...params,
        ...(this.urlParams.search && { search: this.urlParams.search }),
      };

      updateHistory({
        url: setUrlParams(updatedParams, { url: window.location.href, clearParams: true }),
      });
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
        @clear="searchCacheEntries([''])"
      />
    </div>

    <cache-entries-table
      :cache-entries="cacheEntries"
      :loading="cacheEntriesLoading"
      @delete="handleDeleteCacheEntry"
    />

    <div class="gl-flex gl-justify-center">
      <gl-keyset-pagination v-bind="pageInfo" @next="handleNextPage" @prev="handlePreviousPage" />
    </div>
  </div>
</template>
