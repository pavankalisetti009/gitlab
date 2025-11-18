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
      noLongerDetectedAlertDismissed: null,
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
        return (
          [null, true].includes(this.autoResolveAlertDismissed) &&
          [null, true].includes(this.noLongerDetectedAlertDismissed)
        );
      },
    },
  },

  computed: {
    autoResolveAlertKey() {
      return `${this.scope}_security_dashboard_auto_resolve_alert`;
    },
    noLongerDetectedAlertKey() {
      return `${this.scope}_security_dashboard_no_longer_detected_alert`;
    },
  },
  created() {
    this.autoResolveAlertDismissed = getStorageValue(this.autoResolveAlertKey).exists;
    this.noLongerDetectedAlertDismissed = getStorageValue(this.noLongerDetectedAlertKey).exists;
  },
  methods: {
    closeAutoResolveAlert() {
      this.autoResolveAlertDismissed = true;
      saveStorageValue(this.autoResolveAlertKey, true);
    },
    closeNoLongerDetectedAlert() {
      this.noLongerDetectedAlertDismissed = true;
      saveStorageValue(this.noLongerDetectedAlertKey, true);
    },
  },
  securityDashboardHelpLink: helpPagePath('user/application_security/security_dashboard/_index'),
};
</script>

<template>
  <div class="gl-grid gl-w-full gl-gap-5">
    <span>
      <gl-sprintf
        :message="
          s__(
            'SecurityReports|Panels that categorize vulnerabilities as open include those with Needs triage or Confirmed status. To interact with a link in a chart popover, click to pin the popover first. To unstick it, click outside the popover. %{learnMoreStart}Learn more%{learnMoreEnd}',
          )
        "
      >
        <template #learnMore="{ content }">
          <gl-link :href="$options.securityDashboardHelpLink" target="_blank">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
    </span>
    <template v-if="hasNoPolicies">
      <gl-alert
        v-if="!autoResolveAlertDismissed"
        :title="s__('SecurityReports|Recommendation: Auto-resolve when no longer detected')"
        :primary-button-text="s__('SecurityReports|Go to policies')"
        :primary-button-link="securityPoliciesPath"
        data-testid="auto-resolve-alert"
        @dismiss="closeAutoResolveAlert"
      >
        {{
          s__(
            'SecurityReports|To ensure that open vulnerabilities include only vulnerabilities that are still detected, use a vulnerability management policy to automatically resolve vulnerabilities that are no longer detected.',
          )
        }}
      </gl-alert>
      <gl-alert
        v-if="!noLongerDetectedAlertDismissed"
        variant="warning"
        data-testid="no-longer-detected-alert"
        @dismiss="closeNoLongerDetectedAlert"
      >
        {{
          s__(
            'SecurityReports|The vulnerabilities over time chart includes vulnerabilities that are no longer detected and might include more vulnerabilities than the totals shown in the counts per severity or in the vulnerability report.',
          )
        }}
      </gl-alert>
    </template>
  </div>
</template>
