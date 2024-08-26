<script>
import { GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { humanizeRules } from 'ee/security_orchestration/components/policy_drawer/scan_result/utils';
import { policyHasNamespace } from 'ee/security_orchestration/components/utils';
import PolicyApprovals from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_approvals.vue';

export default {
  i18n: {
    policyDetails: s__('SecurityOrchestration|Edit policy'),
  },
  components: {
    GlLink,
    PolicyApprovals,
  },
  props: {
    policy: {
      type: Object,
      required: true,
    },
  },
  computed: {
    policyAction() {
      return this.policy.actions.find((action) => action.type === 'require_approval');
    },
    humanizedRules() {
      return humanizeRules(this.policy.rules);
    },
    showEditLink() {
      return this.policy?.source?.inherited ? policyHasNamespace(this.policy.source) : true;
    },
    approvers() {
      return this.policy.approvers;
    },
  },
};
</script>

<template>
  <tr v-if="policy.isSelected">
    <td colspan="4" class="!gl-border-t-0 !gl-pt-0">
      <div
        class="gl-rounded-base gl-border-1 gl-border-solid gl-border-gray-100 gl-bg-white gl-px-5 gl-py-4"
      >
        <policy-approvals :action="policyAction" :approvers="approvers" />
        <div
          v-for="{ summary, criteriaList } in humanizedRules"
          :key="summary"
          class="gl-mb-1 gl-mt-5"
        >
          {{ summary }}
          <ul class="gl-m-0">
            <li v-for="criteria in criteriaList" :key="criteria">
              {{ criteria }}
            </li>
          </ul>
        </div>
        <div v-if="showEditLink" class="gl-text-right">
          <gl-link :href="policy.editPath" target="_blank">
            {{ $options.i18n.policyDetails }}
          </gl-link>
        </div>
      </div>
    </td>
  </tr>
</template>
