<script>
import { isEmpty } from 'lodash';
import { GlButton, GlSprintf, GlCollapse } from '@gitlab/ui';
import { s__ } from '~/locale';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import {
  ANY_OPERATOR,
  BRANCH_EXCEPTIONS_KEY,
  GREATER_THAN_OPERATOR,
  SCAN_RESULT_BRANCH_TYPE_OPTIONS,
  VULNERABILITIES_ALLOWED_OPERATORS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { enforceIntValue } from 'ee/security_orchestration/components/policy_editor/utils';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/severity_filter.vue';
import StatusFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filters.vue';
import AttributeFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/attribute_filter.vue';
import {
  STATUS,
  FALSE_POSITIVE,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import {
  buildFiltersFromRule,
  groupVulnerabilityStatesWithDefaults,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { normalizeVulnerabilityStates, enableStatusFilter } from './utils';

export default {
  VULNERABILITIES_ALLOWED_OPERATORS,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  FALSE_POSITIVE,
  FILTER_OPTIONS: [
    {
      text: s__('ScanResultPolicy|New status'),
      value: STATUS,
      tooltip: s__('ScanResultPolicy|Maximum of two status criteria allowed'),
    },
  ],
  i18n: {
    title: s__('SecurityOrchestration|SAST Scanning Rule'),
    scanResultRuleCopy: s__(
      'SecurityOrchestration|Runs against %{branches} %{branchExceptions} and finds %{vulnerabilitiesNumber} vulnerability type that matches all the following criteria:',
    ),
    vulnerabilitiesAllowed: s__('SecurityOrchestration|vulnerabilities allowed'),
  },
  name: 'SastScanner',
  components: {
    NumberRangeSelect,
    BranchSelection,
    BranchExceptionSelector,
    GlButton,
    GlCollapse,
    GlSprintf,
    SectionLayout,
    SeverityFilter,
    StatusFilters,
    AttributeFilter,
    ScanFilterSelector,
  },
  inject: ['namespaceType'],
  props: {
    initRule: {
      type: Object,
      required: true,
    },
    visible: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['changed'],
  data() {
    const filters = buildFiltersFromRule(this.initRule);
    const vulnerabilityAttributes = this.initRule?.vulnerability_attributes || {};

    if (isEmpty(vulnerabilityAttributes)) {
      vulnerabilityAttributes[FALSE_POSITIVE] = false;
    }

    return {
      localVisible: this.visible,
      filters,
      defaultVulnerabilityAttributes: vulnerabilityAttributes,
    };
  },
  computed: {
    branchExceptions() {
      return this.initRule.branch_exceptions;
    },
    branchTypes() {
      return SCAN_RESULT_BRANCH_TYPE_OPTIONS(this.namespaceType);
    },
    collapseIcon() {
      return this.localVisible ? 'chevron-up' : 'chevron-down';
    },
    selectedVulnerabilitiesOperator() {
      return this.vulnerabilitiesAllowed === 0 ? ANY_OPERATOR : GREATER_THAN_OPERATOR;
    },
    vulnerabilitiesAllowed() {
      return enforceIntValue(this.initRule.vulnerabilities_allowed);
    },
    severityLevels() {
      return this.initRule.severity_levels?.length
        ? this.initRule.severity_levels
        : [CRITICAL, HIGH];
    },
    vulnerabilityStates() {
      const vulnerabilityStateGroups = groupVulnerabilityStatesWithDefaults(
        this.initRule.vulnerability_states,
      );
      return {
        [PREVIOUSLY_EXISTING]: vulnerabilityStateGroups[PREVIOUSLY_EXISTING],
        [NEWLY_DETECTED]: vulnerabilityStateGroups[NEWLY_DETECTED],
      };
    },
    falsePositiveValue() {
      const attrs = this.initRule?.vulnerability_attributes || this.defaultVulnerabilityAttributes;
      return attrs[FALSE_POSITIVE] ?? false;
    },
    isStatusFilterSelected() {
      return this.isFilterSelected(NEWLY_DETECTED) || this.isFilterSelected(PREVIOUSLY_EXISTING);
    },
    isStatusSelectorDisabled() {
      return Boolean(
        this.vulnerabilityStates[NEWLY_DETECTED] && this.vulnerabilityStates[PREVIOUSLY_EXISTING],
      );
    },
  },
  watch: {
    initRule(newRule) {
      this.filters = buildFiltersFromRule(newRule);
    },
  },
  methods: {
    isFilterSelected(filter) {
      return Boolean(this.filters[filter]);
    },
    handleVulnerabilitiesOperatorChange(value) {
      if (value === ANY_OPERATOR) {
        this.setVulnerabilitiesAllowed(0);
      }
    },
    setVulnerabilitiesAllowed(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.initRule, ...value });
    },
    setBranchType(value) {
      this.$emit('changed', value);
    },
    toggleCollapse() {
      this.localVisible = !this.localVisible;
    },
    removeExceptions() {
      const rule = { ...this.initRule };
      if (BRANCH_EXCEPTIONS_KEY in rule) {
        delete rule[BRANCH_EXCEPTIONS_KEY];
      }

      this.$emit('changed', rule);
    },
    setRange(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
    setSeverityLevels(value) {
      const rule = { ...this.initRule };
      if (value && value.length > 0) {
        rule.severity_levels = value;
      } else {
        delete rule.severity_levels;
      }
      this.$emit('changed', rule);
    },
    setVulnerabilityStates(vulnerabilityStates) {
      this.triggerChanged({
        vulnerability_states: normalizeVulnerabilityStates(vulnerabilityStates),
      });
    },
    changeStatusGroup(value) {
      this.setVulnerabilityStates(value);
    },
    removeStatusFilter(filter) {
      this.setVulnerabilityStates({
        ...this.vulnerabilityStates,
        [filter]: null,
      });
    },
    setFalsePositiveValue(value) {
      this.triggerChanged({
        vulnerability_attributes: { [FALSE_POSITIVE]: value },
      });
    },
    selectFilter(filter) {
      switch (filter) {
        case STATUS:
          this.filters = enableStatusFilter(this.filters);
          break;
        default:
          this.filters = {
            ...this.filters,
            [filter]: [],
          };
      }
    },
    shouldDisableFilter(filter) {
      if (filter === STATUS) {
        return this.isStatusSelectorDisabled;
      }
      return false;
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-flex" :class="{ 'gl-mb-3': localVisible }">
      <gl-button
        category="tertiary"
        :area-label="collapseIcon"
        :icon="collapseIcon"
        @click="toggleCollapse"
      />
      <h5>{{ $options.i18n.title }}</h5>
    </div>

    <gl-collapse v-model="localVisible">
      <section-layout class="gl-bg-white" :show-remove-button="false">
        <template #content>
          <gl-sprintf :message="$options.i18n.scanResultRuleCopy">
            <template #branches>
              <branch-selection
                :init-rule="initRule"
                :branch-types="branchTypes"
                @changed="triggerChanged($event)"
                @set-branch-type="setBranchType"
              />
            </template>

            <template #branchExceptions>
              <branch-exception-selector
                :selected-exceptions="branchExceptions"
                @remove="removeExceptions"
                @select="triggerChanged"
              />
            </template>

            <template #vulnerabilitiesNumber>
              <number-range-select
                id="vulnerabilities-allowed"
                :value="vulnerabilitiesAllowed"
                :label="$options.i18n.vulnerabilitiesAllowed"
                :selected="selectedVulnerabilitiesOperator"
                :operators="$options.VULNERABILITIES_ALLOWED_OPERATORS"
                @operator-change="handleVulnerabilitiesOperatorChange"
                @input="setRange"
              />
            </template>
          </gl-sprintf>
        </template>
      </section-layout>

      <section-layout
        class="gl-mt-4 gl-bg-white gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <severity-filter
            class="!gl-bg-white"
            :selected="severityLevels"
            @input="setSeverityLevels"
          />
        </template>
      </section-layout>

      <section-layout
        v-if="isStatusFilterSelected"
        class="gl-mt-4 gl-bg-white gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <status-filters
            :filters="filters"
            :selected="vulnerabilityStates"
            @change-status-group="changeStatusGroup"
            @input="setVulnerabilityStates"
            @remove="removeStatusFilter"
          />
        </template>
      </section-layout>

      <section-layout
        class="gl-mt-4 gl-bg-white gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <attribute-filter
            :attribute="$options.FALSE_POSITIVE"
            :operator-value="falsePositiveValue"
            :disabled="true"
            :show-remove-button="false"
            @input="setFalsePositiveValue"
          />
        </template>
      </section-layout>

      <section-layout
        class="gl-mt-4 gl-bg-white gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <div class="gl-w-full">
            <scan-filter-selector
              class="gl-w-full !gl-bg-default"
              :filters="$options.FILTER_OPTIONS"
              :selected="filters"
              :should-disable-filter="shouldDisableFilter"
              @select="selectFilter"
            />
          </div>
        </template>
      </section-layout>
    </gl-collapse>
  </div>
</template>
