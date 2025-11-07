<script>
import { GlSprintf, GlLink, GlAlert } from '@gitlab/ui';
import { getStorageValue, saveStorageValue } from '~/lib/utils/local_storage';
import { helpPagePath } from '~/helpers/help_page_helper';
import projectVulnerabilityManagementPolicies from 'ee/security_dashboard/graphql/queries/project_vulnerability_management_policies.query.graphql';
import groupVulnerabilityManagementPolicies from 'ee/security_dashboard/graphql/queries/group_vulnerability_management_policies.query.graphql';

export default {
  name: 'SecurityDashboardDescription',
  components: {
    GlSprintf,
    GlLink,
    GlAlert,
  },
  inject: {
    fullPath: {
      type: String,
      required: true,
    },
    securityPoliciesPath: {
      type: String,
      required: true,
    },
  },
  props: {
    scope: {
      type: String,
      required: true,
      validator: (value) => ['project', 'group'].includes(value),
    },
  },
  data() {
    return {
      hasNoPolicies: false,
      autoResolveAlertDismissed: null,
    };
  },
  apollo: {
    hasNoPolicies: {
      query() {
        return this.scope === 'project'
          ? projectVulnerabilityManagementPolicies
          : groupVulnerabilityManagementPolicies;
      },
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        const policies = data.namespace?.vulnerabilityManagementPolicies?.nodes || [];
        return policies.length === 0;
      },
      // Skip query (with null value) until localStorage item is retrieved, when it's either true or false
      skip() {
        return [null, true].includes(this.autoResolveAlertDismissed);
      },
    },
  },

  computed: {
    autoResolveAlertKey() {
      return `${this.scope}_security_dashboard_auto_resolve_alert`;
    },
  },
  created() {
    this.autoResolveAlertDismissed = getStorageValue(this.autoResolveAlertKey).exists;
  },
  methods: {
    closeAlert() {
      this.autoResolveAlertDismissed = true;
      saveStorageValue(this.autoResolveAlertKey, true);
    },
  },
  securityDashboardHelpLink: helpPagePath('user/application_security/security_dashboard/_index'),
};
</script>

<template>
  <div>
    <gl-sprintf
      :message="
        s__(
          'SecurityReports|Panels that categorize vulnerabilities as open include those with Needs triage or Confirmed status. To interact with a link in a chart popover, click to pin the popover first. To unstick it, click outside the popover. %{learnMoreStart}Learn more%{learnMoreEnd}',
        )
      "
    >
      <template #learnMore="{ content }">
        <gl-link :href="$options.securityDashboardHelpLink" target="_blank">{{ content }}</gl-link>
      </template>
    </gl-sprintf>
    <gl-alert
      v-if="hasNoPolicies && !autoResolveAlertDismissed"
      :title="s__('SecurityReports|Recommendation: Auto-resolve when no longer detected')"
      :primary-button-text="s__('SecurityReports|Go to Policies')"
      :primary-button-link="securityPoliciesPath"
      class="gl-mt-5"
      @dismiss="closeAlert"
    >
      {{
        s__(
          'SecurityReports|To ensure that open vulnerabilities only include vulnerabilities that are still detected, we recommend enabling the policy to auto-resolve vulnerabilities when no longer detected.',
        )
      }}</gl-alert
    >
  </div>
</template>
