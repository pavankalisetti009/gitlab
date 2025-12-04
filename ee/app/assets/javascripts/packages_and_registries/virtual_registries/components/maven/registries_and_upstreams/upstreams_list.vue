<script>
import {
  GlAlert,
  GlEmptyState,
  GlFilteredSearch,
  GlKeysetPagination,
  GlSkeletonLoader,
} from '@gitlab/ui';
import emptyStateIllustrationUrl from '@gitlab/svgs/dist/illustrations/empty-state/empty-radar-md.svg?url';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import getMavenUpstreamsQuery from '../../../graphql/queries/get_maven_upstreams.query.graphql';
import { captureException } from '../../../sentry_utils';
import UpstreamsTable from './upstreams_table.vue';

const INITIAL_VALUE = {
  nodes: [],
  pageInfo: {},
};

export default {
  name: 'MavenUpstreamsList',
  components: {
    EmptyResult,
    GlAlert,
    GlEmptyState,
    GlFilteredSearch,
    GlKeysetPagination,
    GlSkeletonLoader,
    UpstreamsTable,
  },
  inject: ['fullPath'],
  props: {
    searchTerm: {
      type: String,
      required: false,
      default: null,
    },
    pageParams: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      alertMessage: '',
      isLoading: 0,
      mavenUpstreams: INITIAL_VALUE,
      upstreamDeleteSuccessMessage: '',
    };
  },
  apollo: {
    mavenUpstreams: {
      query: getMavenUpstreamsQuery,
      loadingKey: 'isLoading',
      variables() {
        return this.queryVariables;
      },
      update: (data) => data.group?.virtualRegistriesPackagesMavenUpstreams ?? INITIAL_VALUE,
      error(error) {
        this.alertMessage =
          error.message ||
          s__('VirtualRegistry|Failed to fetch list of maven upstream registries.');
        captureException({ error, component: this.$options.name });
      },
    },
  },
  computed: {
    filteredSearchValue() {
      return [
        {
          type: 'filtered-search-term',
          value: { data: this.searchTerm || '' },
        },
      ];
    },
    queryVariables() {
      return {
        groupPath: this.fullPath,
        upstreamName: this.searchTerm,
        ...this.pageParams,
      };
    },
    hasSearchTerm() {
      return Boolean(this.searchTerm?.length);
    },
    showUpstreamsTable() {
      return this.hasUpstreams || this.hasSearchTerm;
    },
    upstreams() {
      return this.mavenUpstreams.nodes.map((upstream) => ({
        ...upstream,
        id: getIdFromGraphQLId(upstream.id),
      }));
    },
    pageInfo() {
      return this.mavenUpstreams.pageInfo;
    },
    hasUpstreams() {
      return this.upstreams.length > 0;
    },
  },
  methods: {
    handleNextPage() {
      this.$emit('page-change', { after: this.pageInfo.endCursor });
    },
    handlePreviousPage() {
      this.$emit('page-change', { before: this.pageInfo.startCursor });
    },
    clearSearch() {
      this.$emit('submit', null);
    },
    searchUpstreams(filters) {
      const [searchTerm] = filters;
      this.$emit('submit', searchTerm);
    },
    handleUpstreamDelete() {
      this.upstreamDeleteSuccessMessage = s__('VirtualRegistry|Maven upstream has been deleted.');
      this.$emit('upstream-deleted');
    },
    setAlertMessage(message = '') {
      this.alertMessage = message;
    },
  },
  emptyStateIllustrationUrl,
};
</script>

<template>
  <div>
    <gl-alert v-if="upstreamDeleteSuccessMessage" @dismiss="upstreamDeleteSuccessMessage = ''">
      {{ upstreamDeleteSuccessMessage }}
    </gl-alert>
    <div v-if="showUpstreamsTable">
      <div
        class="gl-flex gl-flex-col gl-gap-3 gl-border-y-0 gl-bg-subtle gl-p-5 @md/panel:gl-flex-row"
      >
        <gl-filtered-search
          class="gl-min-w-0 gl-grow"
          :placeholder="__('Filter results')"
          :search-text-option-label="__('Search for this text')"
          :value="filteredSearchValue"
          terms-as-tokens
          @submit="searchUpstreams"
          @clear="clearSearch"
        />
      </div>
      <gl-alert v-if="alertMessage" variant="danger" @dismiss="setAlertMessage">
        {{ alertMessage }}
      </gl-alert>
      <upstreams-table
        v-if="hasUpstreams"
        :upstreams="upstreams"
        :busy="Boolean(isLoading)"
        @upstreamDeleted="handleUpstreamDelete"
        @upstreamDeleteFailed="setAlertMessage"
      />
      <empty-result v-else />
      <div class="gl-flex gl-justify-center">
        <gl-keyset-pagination v-bind="pageInfo" @next="handleNextPage" @prev="handlePreviousPage" />
      </div>
    </div>
    <div v-else>
      <gl-alert v-if="alertMessage" variant="danger" :dismissible="false">
        {{ alertMessage }}
      </gl-alert>
      <gl-skeleton-loader v-else-if="isLoading" :lines="2" :width="500" />
      <gl-empty-state
        v-else
        :svg-path="$options.emptyStateIllustrationUrl"
        :title="s__('VirtualRegistry|Connect Maven virtual registry to an upstream')"
        :description="
          s__(
            'VirtualRegistry|Configure an upstream registry to manage Maven artifacts and cache entries.',
          )
        "
      />
    </div>
  </div>
</template>
