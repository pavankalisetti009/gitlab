<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import { get, uniqBy } from 'lodash';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import MergeChecksMessage from '~/vue_merge_request_widget/components/checks/message.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';
import getPolicyViolations from 'ee/merge_requests/reports/queries/policy_violations.query.graphql';
import SecurityPolicyViolationsModal from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_modal.vue';
import { getSelectedModeOption } from './utils';

export default {
  BYPASS_POLICY_ENFORCEMENT_TYPES: ['WARN'],
  HELP_ICON_ID: 'security-policy-help-icon',
  name: 'MergeChecksSecurityPolicyViolations',
  components: {
    ActionButtons,
    GlIcon,
    GlPopover,
    MergeChecksMessage,
    SecurityPolicyViolationsModal,
  },
  apollo: {
    policies: {
      query: getPolicyViolations,
      variables() {
        return { iid: this.mr.iid.toString(), projectPath: this.mr.targetProjectFullPath };
      },
      update(data) {
        const policies = get(data, 'project.mergeRequest.policyViolations.policies', []);
        return uniqBy(policies, 'securityPolicyId');
      },
    },
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    mr: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    check: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      policies: [],
      showModal: false,
      selectedModeOption: getSelectedModeOption(this.mr),
    };
  },
  computed: {
    allowBypass() {
      return Boolean(this.mr.allowBypass);
    },
    bypassPolicies() {
      return this.policies.filter((policy) =>
        this.$options.BYPASS_POLICY_ENFORCEMENT_TYPES.includes(policy.enforcementType),
      );
    },
    enableBypassButton() {
      return Boolean(this.bypassPolicies.filter((policy) => !policy.dismissed).length);
    },
    hasBypassFeatureFlags() {
      return this.warnModeEnabled || this.bypassOptionsEnabled;
    },
    showBypassButton() {
      return (
        this.hasBypassFeatureFlags &&
        this.mr.securityPoliciesPath &&
        Boolean(this.bypassPolicies.length)
      );
    },
    tertiaryActionsButtons() {
      return [
        this.mr.securityPoliciesPath && {
          href: this.mr.securityPoliciesPath,
          text: s__('MergeChecks|View policies'),
          testId: 'view-policies-button',
        },
        this.showBypassButton && {
          onClick: () => this.toggleModal(true),
          disabled: !this.enableBypassButton,
          testId: 'bypass-button',
          text: this.bypassButtonText,
        },
      ].filter((x) => x);
    },
    bypassButtonText() {
      return this.enableBypassButton ? s__('MergeChecks|Bypass') : s__('MergeChecks|Bypassed');
    },
    warnModeEnabled() {
      return this.glFeatures.securityPolicyApprovalWarnMode;
    },
    bypassOptionsEnabled() {
      return this.glFeatures.securityPoliciesBypassOptionsMrWidget && this.allowBypass;
    },
  },
  methods: {
    toggleModal(value) {
      this.showModal = value;
    },
    selectMode(mode) {
      this.selectedModeOption = mode;
    },
  },
};
</script>

<template>
  <merge-checks-message :check="check">
    <template v-if="check.status !== 'INACTIVE'">
      <div v-if="showBypassButton">
        <gl-icon
          :id="$options.HELP_ICON_ID"
          data-testid="security-policy-help-icon"
          name="information-o"
          variant="info"
          class="gl-mr-3"
        />
        <gl-popover
          :target="$options.HELP_ICON_ID"
          data-testid="security-policy-help-popover"
          placement="top"
        >
          <template #title>{{ s__('MergeChecks|Bypass security policies') }}</template>
          <p class="gl-mb-0">
            {{
              s__(
                'MergeChecks|Dismissing a finding will create an audit event. If this finding is merged into the default branch, it will be marked as a policy violation in the vulnerability report.',
              )
            }}
          </p>
        </gl-popover>
      </div>
      <action-buttons :tertiary-buttons="tertiaryActionsButtons" />
      <security-policy-violations-modal
        v-if="showModal"
        v-model="showModal"
        :mr="mr"
        :policies="bypassPolicies"
        :mode="selectedModeOption"
        @close="toggleModal(false)"
        @select-mode="selectMode"
      />
    </template>
  </merge-checks-message>
</template>
