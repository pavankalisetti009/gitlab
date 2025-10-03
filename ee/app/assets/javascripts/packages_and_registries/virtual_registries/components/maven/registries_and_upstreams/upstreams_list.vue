<script>
import { GlAlert, GlEmptyState, GlFilteredSearch, GlSkeletonLoader } from '@gitlab/ui';
import emptyStateIllustrationUrl from '@gitlab/svgs/dist/illustrations/empty-state/empty-radar-md.svg?url';
import { s__ } from '~/locale';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import { getMavenUpstreamRegistriesList } from 'ee/api/virtual_registries_api';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { captureException } from '../../../sentry_utils';
import UpstreamsTable from './upstreams_table.vue';

export default {
  name: 'MavenUpstreamsList',
  components: {
    EmptyResult,
    GlAlert,
    GlEmptyState,
    GlFilteredSearch,
    GlSkeletonLoader,
    UpstreamsTable,
  },
  inject: ['fullPath'],
  data() {
    return {
      alertMessage: '',
      isLoading: false,
      searchTerm: '',
      mavenUpstreams: [],
    };
  },
  computed: {
    hasSearchTerm() {
      return this.searchTerm.length > 0;
    },
    isSearching() {
      return this.hasSearchTerm && this.isLoading;
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
  },
  created() {
    this.fetchMavenUpstreamRegistriesList();
  },
  methods: {
    async fetchMavenUpstreamRegistriesList(searchTerm = '') {
      this.searchTerm = searchTerm;
      this.alertMessage = '';
      try {
        this.isLoading = true;
        const response = await getMavenUpstreamRegistriesList({
          id: this.fullPath,
          params: {
            upstream_name: this.searchTerm,
          },
        });

        this.mavenUpstreams = response.data;
        this.$emit('updateCount', response.headers['x-total']);
      } catch (error) {
        this.alertMessage =
          error.message ||
          s__('VirtualRegistry|Failed to fetch list of maven upstream registries.');
        captureException({ error, component: this.$options.name });
      } finally {
        this.isLoading = false;
      }
    },
    searchUpstreams(filters) {
      const [searchTerm] = filters;
      this.fetchMavenUpstreamRegistriesList(searchTerm);
    },
  },
  emptyStateIllustrationUrl,
};
</script>

<template>
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
    <gl-alert v-if="alertMessage" variant="danger" :dismissible="false">
      {{ alertMessage }}
    </gl-alert>
    <upstreams-table v-if="hasUpstreams" :upstreams="upstreams" :busy="isSearching" />
    <empty-result v-else />
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
</template>
