<script>
import { GlButton, GlSprintf, GlTableLite } from '@gitlab/ui';
import { sprintf, __ } from '~/locale';
import ReviewerDropdown from '~/merge_requests/components/reviewers/reviewer_dropdown.vue';
import EmptyRuleApprovers from 'ee/approvals/components/rules/empty_rule_approvers.vue';
import { RULE_TYPE_ANY_APPROVER, RULE_TYPE_CODE_OWNER } from 'ee/approvals/constants';

export default {
  components: {
    GlButton,
    GlSprintf,
    GlTableLite,
    ReviewerDropdown,
    EmptyRuleApprovers,
  },
  props: {
    group: {
      type: Object,
      required: true,
    },
    reviewers: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      showingOptional: false,
    };
  },
  computed: {
    filteredRules() {
      return this.group.rules
        .filter(({ approvalsRequired }) => {
          return this.showingOptional ? true : approvalsRequired;
        })
        .sort((a, b) => b.approvalsRequired - a.approvalsRequired);
    },
    optionalRulesLength() {
      return this.group.rules.filter(({ approvalsRequired }) => !approvalsRequired).length;
    },
  },
  methods: {
    toggleOptionalRules() {
      this.showingOptional = !this.showingOptional;
    },
    getApprovalsLeftText(rule) {
      return sprintf(__('%{approvals} of %{approvalRequired}'), {
        approvals: rule.approvedBy.nodes.length,
        approvalRequired: rule.approvalsRequired,
      });
    },
  },
  fields: [
    {
      key: 'rule_name',
      thClass: '!gl-text-secondary !gl-text-sm !gl-font-semibold !gl-border-t-0 w-60p',
      class: '!gl-px-0 !gl-pr-4 !gl-py-4 gl-break-words',
    },
    {
      key: 'rule_approvals',
      thClass: '!gl-text-secondary !gl-text-sm !gl-font-semibold !gl-border-t-0 w-30p',
      class: '!gl-px-0 !gl-py-4',
    },
    {
      key: 'dropdown',
      label: '',
      thClass: '!gl-border-t-0 w-30p',
      class: '!gl-px-0 !gl-py-4',
    },
  ],
  ANY_APPROVER: RULE_TYPE_ANY_APPROVER.toUpperCase(),
  CODE_OWNERS: RULE_TYPE_CODE_OWNER.toUpperCase(),
};
</script>

<template>
  <div class="gl-mb-2">
    <gl-table-lite :items="filteredRules" :fields="$options.fields" class="!gl-mb-0 gl-table-fixed">
      <template #head(rule_name)>{{ group.label }}</template>
      <template #head(rule_approvals)>{{ __('Approvals') }}</template>

      <template #cell(rule_name)="{ item }">
        <empty-rule-approvers
          v-if="item.type === $options.ANY_APPROVER"
          popover-id="sidebar-pop-approver"
          popover-container-id="sidebar-popover-container"
        />
        <template v-else>
          <span
            v-if="item.section && item.section !== 'codeowners'"
            class="gl-block"
            data-testid="section-name"
          >
            {{ item.section }}
          </span>
          <span :class="{ 'gl-text-sm gl-font-monospace': item.type === $options.CODE_OWNERS }">
            {{ item.name }}
          </span>
        </template>
      </template>
      <template #cell(rule_approvals)="{ item }">{{ getApprovalsLeftText(item) }}</template>
      <template #cell(dropdown)="{ item }">
        <div class="gl-flex gl-justify-end">
          <reviewer-dropdown :selected-reviewers="reviewers" :users="item.eligibleApprovers" />
        </div>
      </template>
    </gl-table-lite>
    <div v-if="optionalRulesLength" class="gl-border-b gl-py-3">
      <gl-button
        category="tertiary"
        size="small"
        :icon="showingOptional ? 'chevron-up' : 'chevron-right'"
        data-testid="optional-rules-toggle"
        @click="toggleOptionalRules(group)"
      >
        <gl-sprintf :message="__('%{count} optional %{label}.')">
          <template #count>{{ optionalRulesLength }}</template>
          <template #label>{{ group.label.toLowerCase() }}</template>
        </gl-sprintf>
      </gl-button>
    </div>
  </div>
</template>
