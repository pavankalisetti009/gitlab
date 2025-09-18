<script>
import { get, uniqBy } from 'lodash';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import MergeChecksMessage from '~/vue_merge_request_widget/components/checks/message.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';
import getPolicyViolations from 'ee/merge_requests/reports/queries/policy_violations.query.graphql';
import SecurityPolicyViolationsModal from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_modal.vue';
import { getSelectedModeOption } from './utils';

export default {
  name: 'MergeChecksSecurityPolicyViolations',
  components: {
    ActionButtons,
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
        const uniquePolicies = uniqBy(policies, 'name');
        return uniquePolicies.map((policy) => ({
          ...policy,
          text: policy.name,
          value: policy.name,
        }));
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
    enableBypassButton() {
      return this.warnModeEnabled || this.bypassOptionsEnabled;
    },
    showBypassButton() {
      return (
        this.enableBypassButton && this.mr.securityPoliciesPath && Boolean(this.policies.length)
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
          text: s__('MergeChecks|Bypass'),
          testId: 'bypass-button',
        },
      ].filter((x) => x);
    },
    warnModeEnabled() {
      return this.glFeatures.securityPolicyApprovalWarnMode;
    },
    bypassOptionsEnabled() {
      return this.glFeatures.securityPoliciesBypassOptionsMrWidget && this.mr.allowBypass;
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
      <action-buttons :tertiary-buttons="tertiaryActionsButtons" />
      <security-policy-violations-modal
        v-if="showModal"
        v-model="showModal"
        :policies="policies"
        :mode="selectedModeOption"
        @close="toggleModal(false)"
        @select-mode="selectMode"
      />
    </template>
  </merge-checks-message>
</template>
