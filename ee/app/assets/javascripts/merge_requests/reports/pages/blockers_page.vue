<script>
import { GlLoadingIcon } from '@gitlab/ui';
import projectPoliciesQuery from '../queries/project_policies.query.graphql';
import policyViolationsQuery from '../queries/policy_violations.query.graphql';
import SecurityListItem from '../components/security_list_item.vue';

const VIOLATIONS_DATA_MAP = {
  ANY_MERGE_REQUEST: 'anyMergeRequest',
  SCAN_FINDING: 'newScanFinding',
};

export default {
  name: 'MergeRequestReportsBlocksPage',
  apollo: {
    policies: {
      query: projectPoliciesQuery,
      variables() {
        return { projectPath: this.projectPath };
      },
      update: (d) => (d.project?.approvalPolicies?.nodes || []).filter((p) => p.enabled),
      context: {
        batchKey: 'PolicyBlockers',
      },
    },
    policyViolations: {
      query: policyViolationsQuery,
      variables() {
        return { projectPath: this.projectPath, iid: this.iid };
      },
      update: (d) => d.project?.mergeRequest?.policyViolations || {},
      context: {
        batchKey: 'PolicyBlockers',
      },
    },
  },
  components: {
    GlLoadingIcon,
    SecurityListItem,
  },
  inject: ['projectPath', 'iid'],
  data() {
    return {
      policies: [],
      policyViolations: {},
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.policies.loading || this.$apollo.queries.policyViolations.loading;
    },
  },
  methods: {
    getFindingsForPolicyForName(name) {
      const policy = this.policyViolations.policies?.find((p) => p.name === name);

      if (!policy) return [];

      const propertyKey = VIOLATIONS_DATA_MAP[policy.reportType];

      return this.policyViolations[propertyKey];
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="lg" />
    <template v-else>
      <security-list-item
        v-for="(policy, index) in policies"
        :key="index"
        :policy-name="policy.name"
        :findings="getFindingsForPolicyForName(policy.name)"
        :loading="false"
        class="gl-mb-3 gl-pb-3"
        :class="{ 'gl-border-b': index !== policies.length - 1 }"
      />
    </template>
  </div>
</template>
