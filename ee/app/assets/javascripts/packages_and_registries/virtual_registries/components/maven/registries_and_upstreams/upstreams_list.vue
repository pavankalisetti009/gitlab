<script>
import {
  GlAlert,
  GlEmptyState,
  GlFilteredSearch,
  GlPagination,
  GlSkeletonLoader,
} from '@gitlab/ui';
import emptyStateIllustrationUrl from '@gitlab/svgs/dist/illustrations/empty-state/empty-radar-md.svg?url';
import { s__ } from '~/locale';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import { getMavenUpstreamRegistriesList } from 'ee/api/virtual_registries_api';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { captureException } from '../../../sentry_utils';
import UpstreamsTable from './upstreams_table.vue';

const PAGE_SIZE = 20;
const INITIAL_PAGE = 1;

export default {
  name: 'MavenUpstreamsList',
  perPage: PAGE_SIZE,
  components: {
    EmptyResult,
    GlAlert,
    GlEmptyState,
    GlFilteredSearch,
    GlPagination,
    GlSkeletonLoader,
    UpstreamsTable,
  },
  inject: ['fullPath'],
  data() {
    return {
      alertMessage: '',
      isLoading: false,
      searchTerm: '',
      page: INITIAL_PAGE,
      mavenUpstreams: [],
      mavenUpstreamsTotalCount: 0,
      upstreamDeleteSuccessMessage: '',
    };
  },
  computed: {
    hasSearchTerm() {
      return this.searchTerm.length > 0;
    },
    showUpstreamsTable() {
      return this.mavenUpstreams.length > 0 || this.hasSearchTerm;
    },
    upstreams() {
      return this.mavenUpstreams.map((upstream) => {
        const { id, name, url, cacheValidityHours, metadataCacheValidityHours } =
          convertObjectPropsToCamelCase(upstream);
        return { id, name, url, cacheValidityHours, metadataCacheValidityHours };
      });
    },
    hasUpstreams() {
      return this.upstreams.length > 0;
    },
    showPagination() {
      return this.mavenUpstreamsTotalCount > this.$options.perPage;
    },
  },
  created() {
    this.fetchMavenUpstreamRegistriesList();
  },
  methods: {
    async fetchMavenUpstreamRegistriesList(searchTerm = '', page = this.page) {
      this.searchTerm = searchTerm;
      this.setAlertMessage();
      try {
        this.isLoading = true;
        const response = await getMavenUpstreamRegistriesList({
          id: this.fullPath,
          params: {
            upstream_name: this.searchTerm,
            page,
            per_page: PAGE_SIZE,
          },
        });

        this.mavenUpstreamsTotalCount = Number(response.headers['x-total']) || 0;
        this.mavenUpstreams = response.data;
        this.$emit('updateCount', this.mavenUpstreamsTotalCount);
      } catch (error) {
        const alertMessage =
          error.message ||
          s__('VirtualRegistry|Failed to fetch list of maven upstream registries.');
        this.setAlertMessage(alertMessage);
        captureException({ error, component: this.$options.name });
      } finally {
        this.isLoading = false;
      }
    },
    handlePageChange(page) {
      this.page = page;
      this.fetchMavenUpstreamRegistriesList(this.searchTerm);
    },
    searchUpstreams(filters) {
      const [searchTerm] = filters;
      this.page = INITIAL_PAGE;
      this.fetchMavenUpstreamRegistriesList(searchTerm);
    },
    handleUpstreamDelete() {
      this.upstreamDeleteSuccessMessage = s__('VirtualRegistry|Maven upstream has been deleted.');
      this.page = INITIAL_PAGE;
      this.fetchMavenUpstreamRegistriesList(this.searchTerm);
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
          terms-as-tokens
          @submit="searchUpstreams"
        />
      </div>
      <gl-alert v-if="alertMessage" variant="danger" @dismiss="setAlertMessage">
        {{ alertMessage }}
      </gl-alert>
      <upstreams-table
        v-if="hasUpstreams"
        :upstreams="upstreams"
        :busy="isLoading"
        @upstreamDeleted="handleUpstreamDelete"
        @upstreamDeleteFailed="setAlertMessage"
      />
      <empty-result v-else />
      <gl-pagination
        v-if="showPagination"
        :value="page"
        :per-page="$options.perPage"
        :total-items="mavenUpstreamsTotalCount"
        align="center"
        class="gl-mt-5"
        @input="handlePageChange"
      />
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
