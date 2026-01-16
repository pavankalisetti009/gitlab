<script>
import { GlAlert, GlTabs, GlTab } from '@gitlab/ui';
import { n__ } from '~/locale';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import { getPageParams } from '~/packages_and_registries/shared/utils';
import RegistriesList from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/registries_list.vue';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import getMavenUpstreamsCount from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams_count.query.graphql';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

const PAGE_SIZE = 20;
const INITIAL_PAGE_PARAMS = {
  first: PAGE_SIZE,
};

export default {
  name: 'MavenVirtualRegistriesAndUpstreamsApp',
  components: {
    GlAlert,
    GlTabs,
    GlTab,
    RegistriesList,
    CleanupPolicyStatus,
    UpstreamsList: () =>
      import(
        'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/upstreams_list.vue'
      ),
    UserCalloutDismisser,
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
    screenReaderRegistriesTitle() {
      return n__(
        'VirtualRegistry|%d registry',
        'VirtualRegistry|%d registries',
        this.registriesCount || 0,
      );
    },
    screenReaderUpstreamsTitle() {
      return n__(
        'VirtualRegistry|%d upstream',
        'VirtualRegistry|%d upstreams',
        this.upstreamsCount || 0,
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
    <user-callout-dismisser feature-name="virtual_registry_permission_change_alert">
      <template #default="{ dismiss, shouldShowCallout }">
        <gl-alert v-if="shouldShowCallout" class="gl-my-3" @dismiss="dismiss">
          {{
            s__(
              'VirtualRegistry|Direct project membership no longer grants access to the Maven virtual registry. To access the virtual registry, you must be a member of the top-level group or an administrator.',
            )
          }}
        </gl-alert>
      </template>
    </user-callout-dismisser>
    <gl-tabs content-class="gl-p-0" sync-active-tab-with-query-params>
      <gl-tab
        :title="s__('VirtualRegistry|Registries')"
        :tab-count="registriesCount"
        :tab-count-sr-text="screenReaderRegistriesTitle"
        query-param-value="registries"
      >
        <registries-list @updateCount="updateRegistriesCount" />
      </gl-tab>
      <gl-tab
        :title="s__('VirtualRegistry|Upstreams')"
        :tab-count="upstreamsCount"
        :tab-count-sr-text="screenReaderUpstreamsTitle"
        query-param-value="upstreams"
        lazy
      >
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
