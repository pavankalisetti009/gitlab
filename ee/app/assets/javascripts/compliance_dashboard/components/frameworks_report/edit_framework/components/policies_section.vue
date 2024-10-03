<script>
import { GlBadge, GlButton, GlLoadingIcon, GlTable, GlIcon, GlSprintf, GlLink } from '@gitlab/ui';

import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import { getPolicyType } from 'ee/security_orchestration/utils';
import { i18n } from '../constants';
import complianceFrameworkPoliciesQuery from '../graphql/compliance_frameworks_policies.query.graphql';

import EditSection from './edit_section.vue';

function extractPolicies(policies) {
  return {
    policies: policies.nodes,
    hasNextPage: policies.pageInfo.hasNextPage,
    endCursor: policies.pageInfo.endCursor,
  };
}

export default {
  components: {
    DrawerWrapper,
    EditSection,
    GlIcon,
    GlBadge,
    GlButton,
    GlLoadingIcon,
    GlSprintf,
    GlTable,
    GlLink,
  },
  provide() {
    return {
      // required for drawer component
      namespacePath: this.fullPath,
    };
  },
  inject: ['disableScanPolicyUpdate', 'groupSecurityPoliciesPath'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    graphqlId: {
      type: String,
      required: true,
    },
  },

  data() {
    return {
      selectedPolicy: null,
      rawPolicies: {
        globalApprovalPolicies: [],
        globalScanExecutionPolicies: [],
        approvalPolicies: [],
        scanExecutionPolicies: [],
      },
      policiesLoaded: false,
      policiesLoadCursor: {
        approvalPoliciesGlobalAfter: null,
        scanExecutionPoliciesGlobalAfter: null,
        approvalPoliciesAfter: null,
        scanExecutionPoliciesAfter: null,
      },
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    rawGroupPolicies: {
      query: complianceFrameworkPoliciesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          complianceFramework: this.graphqlId,
          ...this.policiesLoadCursor,
        };
      },
      update(data) {
        const {
          policies: pendingGlobalApprovalPolicies,
          hasNextPage: hasNextGlobalApprovalPolicies,
          endCursor: approvalPoliciesGlobalAfter,
        } = extractPolicies(data.namespace.approvalPolicies);
        const {
          policies: pendingGlobalScanExecutionPolicies,
          hasNextPage: hasNextGlobalScanExecutionPolicies,
          endCursor: scanExecutionPoliciesGlobalAfter,
        } = extractPolicies(data.namespace.scanExecutionPolicies);
        const {
          policies: pendingApprovalPolicies,
          hasNextPage: hasNextApprovalPolicies,
          endCursor: approvalPoliciesAfter,
        } = extractPolicies(data.namespace.complianceFrameworks.nodes[0].scanResultPolicies);
        const {
          policies: pendingScanExecutionPolicies,
          hasNextPage: hasNextScanExecutionPolicies,
          endCursor: scanExecutionPoliciesAfter,
        } = extractPolicies(data.namespace.complianceFrameworks.nodes[0].scanExecutionPolicies);

        this.policiesLoaded =
          !hasNextGlobalApprovalPolicies &&
          !hasNextGlobalScanExecutionPolicies &&
          !hasNextApprovalPolicies &&
          !hasNextScanExecutionPolicies;

        const newCursor = {
          approvalPoliciesGlobalAfter,
          scanExecutionPoliciesGlobalAfter,
          approvalPoliciesAfter,
          scanExecutionPoliciesAfter,
        };

        [
          'approvalPoliciesGlobalAfter',
          'scanExecutionPoliciesGlobalAfter',
          'approvalPoliciesAfter',
          'scanExecutionPoliciesAfter',
        ].forEach((cursorField) => {
          if (newCursor[cursorField]) {
            this.policiesLoadCursor[cursorField] = newCursor[cursorField];
          }
        });

        this.rawPolicies.approvalPolicies.push(...pendingApprovalPolicies);
        this.rawPolicies.scanExecutionPolicies.push(...pendingScanExecutionPolicies);
        this.rawPolicies.globalApprovalPolicies.push(...pendingGlobalApprovalPolicies);
        this.rawPolicies.globalScanExecutionPolicies.push(...pendingGlobalScanExecutionPolicies);
      },
      error(error) {
        this.errorMessage = this.$options.i18n.fetchError;
        Sentry.captureException(error);
      },
      skip() {
        return this.policiesLoaded;
      },
    },
  },

  computed: {
    policies() {
      const approvalPoliciesSet = new Set(this.rawPolicies.approvalPolicies.map((p) => p.name));
      const scanExecutionPoliciesSet = new Set(
        this.rawPolicies.scanExecutionPolicies.map((p) => p.name),
      );

      return [
        ...this.rawPolicies.globalApprovalPolicies
          .filter((p) => approvalPoliciesSet.has(p.name))
          .map((p) => ({
            ...p,
            isLinked: true,
          })),
        ...this.rawPolicies.globalScanExecutionPolicies
          .filter((p) => scanExecutionPoliciesSet.has(p.name))
          .map((p) => ({
            ...p,
            isLinked: true,
          })),
      ].sort((a, b) => (a.name > b.name ? 1 : -1));
    },

    policyType() {
      // eslint-disable-next-line no-underscore-dangle
      return this.selectedPolicy ? getPolicyType(this.selectedPolicy.__typename) : '';
    },
  },

  methods: {
    openPolicyDrawerFromRow(rows) {
      if (rows.length === 0) return;
      this.openPolicyDrawer(rows[0]);
    },

    openPolicyDrawer(policy) {
      this.selectedPolicy = policy;
    },

    deselectPolicy() {
      this.selectedPolicy = null;
      this.$refs.policiesTable.$children[0].clearSelected();
    },
  },

  tableFields: [
    {
      key: 'name',
      label: i18n.policiesTableFields.name,
      thClass: '!gl-border-t-0',
      tdClass: '!gl-bg-white md:gl-w-2/5 !gl-border-b-white',
    },
    {
      key: 'description',
      label: i18n.policiesTableFields.desc,
      thClass: '!gl-border-t-0',
      tdClass: '!gl-bg-white md:gl-w-2/5 !gl-border-b-white',
    },
    {
      key: 'action',
      label: i18n.policiesTableFields.action,
      thAlignRight: true,
      thClass: '!gl-border-t-0',
      tdClass: 'gl-text-right md:gl-w-1/5 !gl-bg-white !gl-border-b-white',
    },
  ],
  i18n,
};
</script>

<template>
  <edit-section
    :title="$options.i18n.policies"
    :description="$options.i18n.policiesDescription"
    :items-count="policies.length"
  >
    <gl-table
      v-if="policies.length"
      ref="policiesTable"
      :items="policies"
      :fields="$options.tableFields"
      :busy="$apollo.queries.rawGroupPolicies.loading"
      responsive
      stacked="md"
      hover
      selectable
      select-mode="single"
      selected-variant="primary"
      class="gl-mb-6"
      @row-selected="openPolicyDrawerFromRow"
    >
      <template #cell(name)="{ item }">
        <span>{{ item.name }}</span>
        <gl-badge v-if="!item.enabled" variant="muted" class="gl-ml-2">
          {{ __('Disabled') }}
        </gl-badge>
      </template>
      <template #cell(action)="{ item }">
        <gl-button variant="link" @click="openPolicyDrawer(item)">
          {{ __('View details') }}
        </gl-button>
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" />
      </template>
    </gl-table>
    <drawer-wrapper
      container-class=".content-wrapper"
      :open="Boolean(selectedPolicy)"
      :policy="selectedPolicy"
      :policy-type="policyType"
      :disable-scan-policy-update="disableScanPolicyUpdate"
      @close="deselectPolicy"
    />
    <div class="gl-ml-5" data-testid="info-text">
      <gl-icon name="information-o" variant="subtle" class="gl-mr-2" />
      <gl-sprintf :message="$options.i18n.policiesInfoText">
        <template #link="{ content }">
          <gl-link :href="groupSecurityPoliciesPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </div>
  </edit-section>
</template>
