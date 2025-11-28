<script>
import { GlTabs, GlTab, GlBadge } from '@gitlab/ui';
import { n__, sprintf } from '~/locale';
import { getPageParams } from '~/packages_and_registries/shared/utils';
import RegistriesList from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/registries_list.vue';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import getMavenUpstreamsCount from '../../../graphql/queries/get_maven_upstreams_count.query.graphql';
import { captureException } from '../../../sentry_utils';

const PAGE_SIZE = 20;
const INITIAL_PAGE_PARAMS = {
  first: PAGE_SIZE,
};

export default {
  name: 'MavenVirtualRegistriesAndUpstreamsApp',
  components: {
    GlBadge,
    GlTabs,
    GlTab,
    RegistriesList,
    CleanupPolicyStatus,
    UpstreamsList: () =>
      import(
        'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/upstreams_list.vue'
      ),
  },
  inject: ['fullPath'],
  data() {
    return {
      registriesCount: null,
      upstreamsCount: null,
      upstreamsSearchTerm: null,
      upstreamsPageParams: INITIAL_PAGE_PARAMS,
    };
  },
  apollo: {
    upstreamsCount: {
      query: getMavenUpstreamsCount,
      variables() {
        return {
          groupPath: this.fullPath,
          upstreamName: this.upstreamsSearchTerm,
        };
      },
      update: (data) => data.group?.virtualRegistriesPackagesMavenUpstreams?.count ?? 0,
      error(error) {
        captureException({ error, component: this.$options.name });
      },
    },
  },
  computed: {
    showRegistriesCount() {
      return this.registriesCount !== null;
    },
    showUpstreamsCount() {
      return this.upstreamsCount !== null;
    },
    screenReaderRegistriesTitle() {
      return sprintf(
        n__(
          'VirtualRegistry|%{count} registry',
          'VirtualRegistry|%{count} registries',
          this.registriesCount || 0,
        ),
        { count: this.registriesCount },
      );
    },
    screenReaderUpstreamsTitle() {
      return sprintf(
        n__(
          'VirtualRegistry|%{count} upstream',
          'VirtualRegistry|%{count} upstreams',
          this.upstreamsCount || 0,
        ),
        { count: this.upstreamsCount },
      );
    },
  },
  methods: {
    updateRegistriesCount(newCount) {
      this.registriesCount = newCount;
    },
    handleUpstreamDeleted() {
      this.upstreamsPageParams = INITIAL_PAGE_PARAMS;
      this.$apollo.queries.upstreamsCount.refetch();
    },
    updateUpstreamsSearch(searchTerm) {
      this.upstreamsSearchTerm = searchTerm;
      this.upstreamsPageParams = INITIAL_PAGE_PARAMS;
    },
    updatePageParams(params) {
      this.upstreamsPageParams = getPageParams(params, PAGE_SIZE);
    },
  },
};
</script>

<template>
  <div>
    <cleanup-policy-status batch-key="MavenVirtualRegistries" />
    <gl-tabs content-class="gl-p-0" sync-active-tab-with-query-params>
      <gl-tab query-param-value="registries">
        <template #title>
          <span aria-hidden="true" data-testid="registries-tab-title">{{
            s__('VirtualRegistry|Registries')
          }}</span>
          <gl-badge
            v-if="showRegistriesCount"
            class="gl-tab-counter-badge"
            data-testid="registries-tab-counter-badge"
            aria-hidden="true"
            >{{ registriesCount }}</gl-badge
          >
          <span class="gl-sr-only">{{ screenReaderRegistriesTitle }}</span>
        </template>
        <registries-list @updateCount="updateRegistriesCount" />
      </gl-tab>
      <gl-tab query-param-value="upstreams" lazy>
        <template #title>
          <span aria-hidden="true" data-testid="upstreams-tab-title">{{
            s__('VirtualRegistry|Upstreams')
          }}</span>
          <gl-badge
            v-if="showUpstreamsCount"
            class="gl-tab-counter-badge"
            data-testid="upstreams-tab-counter-badge"
            aria-hidden="true"
            >{{ upstreamsCount }}</gl-badge
          >
          <span class="gl-sr-only">{{ screenReaderUpstreamsTitle }}</span>
        </template>
        <upstreams-list
          :search-term="upstreamsSearchTerm"
          :page-params="upstreamsPageParams"
          @submit="updateUpstreamsSearch"
          @page-change="updatePageParams"
          @upstream-deleted="handleUpstreamDeleted"
        />
      </gl-tab>
    </gl-tabs>
  </div>
</template>
