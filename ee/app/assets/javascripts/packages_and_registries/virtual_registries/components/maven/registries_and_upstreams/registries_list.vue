<script>
import { GlAlert, GlEmptyState, GlKeysetPagination, GlSkeletonLoader } from '@gitlab/ui';
import emptyStateIllustrationUrl from '@gitlab/svgs/dist/illustrations/empty-state/empty-radar-md.svg?url';
import { s__ } from '~/locale';
import { setUrlParams, updateHistory, queryToObject } from '~/lib/utils/url_utility';
import { getPageParams } from '~/packages_and_registries/shared/utils';
import getMavenVirtualRegistries from '../../../graphql/queries/get_maven_virtual_registries.query.graphql';
import { captureException } from '../../../sentry_utils';
import RegistriesTable from './registries_table.vue';

const PAGE_SIZE = 20;
const INITIAL_VALUE = {
  nodes: [],
  pageInfo: {},
};

export default {
  name: 'MavenRegistriesList',
  components: {
    GlAlert,
    GlEmptyState,
    GlKeysetPagination,
    GlSkeletonLoader,
    RegistriesTable,
  },
  inject: ['fullPath'],
  data() {
    return {
      alertMessage: '',
      isLoading: 0,
      mavenRegistries: INITIAL_VALUE,
      pageParams: null,
    };
  },
  computed: {
    hasRegistries() {
      return this.registries.length > 0;
    },
    registries() {
      return this.mavenRegistries.nodes;
    },
    pageInfo() {
      return this.mavenRegistries.pageInfo;
    },
    queryVariables() {
      return {
        groupPath: this.fullPath,
        first: PAGE_SIZE,
        ...this.pageParams,
      };
    },
  },
  apollo: {
    mavenRegistries: {
      query: getMavenVirtualRegistries,
      loadingKey: 'isLoading',
      skip() {
        return this.pageParams === null;
      },
      variables() {
        return this.queryVariables;
      },
      update: (data) => data.group?.mavenVirtualRegistries ?? INITIAL_VALUE,
      result() {
        this.$emit('updateCount', this.registries.length);
      },
      error(error) {
        this.alertMessage =
          error.message || s__('VirtualRegistry|Failed to fetch list of maven virtual registries.');
        captureException({ error, component: this.$options.name });
      },
    },
  },
  created() {
    this.updatePageParamsFromUrl();
    this.addPopstateListener();
  },
  beforeDestroy() {
    this.removePopstateListener();
  },
  methods: {
    addPopstateListener() {
      window.addEventListener('popstate', this.updatePageParamsFromUrl);
    },
    removePopstateListener() {
      window.removeEventListener('popstate', this.updatePageParamsFromUrl);
    },
    updatePageParamsFromUrl() {
      const queryParams = this.parseUrlParams();
      this.pageParams = this.buildPageParams(queryParams);
    },
    parseUrlParams() {
      const queryStringObject = queryToObject(window.location.search);
      return {
        after: queryStringObject?.after ?? null,
        before: queryStringObject?.before ?? null,
      };
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
      updateHistory({
        url: setUrlParams(params, { url: window.location.href, clearParams: true }),
      });
    },
  },
  emptyStateIllustrationUrl,
};
</script>

<template>
  <gl-alert v-if="alertMessage" variant="danger">
    {{ alertMessage }}
  </gl-alert>
  <gl-skeleton-loader v-else-if="isLoading" :lines="2" :width="500" />
  <div v-else-if="hasRegistries">
    <registries-table :registries="registries" />
    <div class="gl-flex gl-justify-center">
      <gl-keyset-pagination v-bind="pageInfo" @next="handleNextPage" @prev="handlePreviousPage" />
    </div>
  </div>
  <gl-empty-state
    v-else
    :svg-path="$options.emptyStateIllustrationUrl"
    :title="s__('VirtualRegistry|There are no maven virtual registries yet')"
  />
</template>
