<script>
import { GlBanner, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { joinPaths, PROMO_URL } from '~/lib/utils/url_utility';
import { DASHBOARD_TYPE_GROUP, DASHBOARD_TYPE_PROJECT } from 'ee/security_dashboard/constants';
import projectVulnerabilityManagementPoliciesQuery from './graphql/first_project_vulnerability_management_policies.query.graphql';
import groupVulnerabilityManagementPoliciesQuery from './graphql/first_group_vulnerability_management_policies.query.graphql';

const query = {
  [DASHBOARD_TYPE_GROUP]: groupVulnerabilityManagementPoliciesQuery,
  [DASHBOARD_TYPE_PROJECT]: projectVulnerabilityManagementPoliciesQuery,
};

export default {
  components: { GlBanner, GlSprintf, GlLink, LocalStorageSync },
  inject: ['fullPath', 'dashboardType'],
  data() {
    return {
      dismissed: false,
      mounted: false,
      vulnerabilityManagementPolicies: [],
    };
  },
  apollo: {
    vulnerabilityManagementPolicies: {
      query() {
        return query[this.dashboardType];
      },
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data?.namespace?.vulnerabilityManagementPolicies?.nodes ?? [];
      },
      skip() {
        return this.dismissed || !this.mounted;
      },
    },
  },
  computed: {
    policiesLink() {
      let policiesPath = `/${this.fullPath}/-/security/policies`;
      if (this.dashboardType === DASHBOARD_TYPE_GROUP) policiesPath = `/groups${policiesPath}`;
      return joinPaths(gon.relative_url_root, policiesPath);
    },
    showBanner() {
      return (
        this.mounted &&
        !this.dismissed &&
        !this.$apollo.queries.vulnerabilityManagementPolicies.loading &&
        !this.vulnerabilityManagementPolicies.length
      );
    },
  },
  mounted() {
    // Skip apollo query until `mounted` is true such that LocalStorageSync has loaded
    // `dismissed` value to prevent unnecessary query if banner was previously dismissed
    this.mounted = true;
  },
  methods: {
    dismiss() {
      this.dismissed = true;
    },
  },
  i18n: {
    message: s__(
      'SecurityReports|To automatically resolve vulnerabilities when they are no longer detected by automated scanning, use the new auto-resolve option in your vulnerability management policies. From the %{boldStart}Policies%{boldEnd} page, configure a policy by applying the %{boldStart}Auto-resolve%{boldEnd} option and make sure the policy is linked to the appropriate projects. You can also configure the policy to auto-resolve only the vulnerabilities of a specific severity or from specific security scanners. See the %{linkStart}release post%{linkEnd} for details.',
    ),
  },
  BANNER_DISMISSED_KEY: 'auto_resolve_banner_dismissed',
  RELEASE_POST_LINK: `${PROMO_URL}/releases/2024/12/19/gitlab-17-7-released/#auto-resolve-vulnerabilities-when-not-found-in-subsequent-scans`,
};
</script>

<template>
  <local-storage-sync v-model="dismissed" :storage-key="$options.BANNER_DISMISSED_KEY">
    <gl-banner
      v-if="showBanner"
      :title="s__('SecurityReports|Auto-resolve vulnerabilities that are no longer detected')"
      :button-text="s__('SecurityReports|Go to policies')"
      :button-link="policiesLink"
      variant="introduction"
      class="gl-mt-5"
      @close="dismiss"
    >
      <p>
        <gl-sprintf :message="$options.i18n.message">
          <template #bold="{ content }">
            <strong>{{ content }}</strong>
          </template>
          <template #link="{ content }">
            <gl-link :href="$options.RELEASE_POST_LINK" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </gl-banner>
  </local-storage-sync>
</template>
