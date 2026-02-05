<script>
import { GlCollapse } from '@gitlab/ui';
import { s__ } from '~/locale';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import {
  ANY_OPERATOR,
  SCAN_RESULT_BRANCH_TYPE_OPTIONS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { enforceIntValue } from 'ee/security_orchestration/components/policy_editor/utils';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/severity_filter.vue';
import StatusFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filter.vue';
import { NEWLY_DETECTED } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import {
  buildFiltersFromRule,
  groupVulnerabilityStatesWithDefaults,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import {
  getSelectedVulnerabilitiesOperator,
  removeExceptionsFromScanner,
  updateSeverityLevels,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';
import BranchRuleSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/branch_rule_section.vue';

export default {
  NEWLY_DETECTED,
  i18n: {
    title: s__('SecurityOrchestration|Secret Detection Scanning Rule'),
  },
  name: 'SecretDetectionScanner',
  components: {
    GlCollapse,
    SectionLayout,
    SeverityFilter,
    StatusFilter,
    ScannerHeader,
    BranchRuleSection,
  },
  inject: ['namespaceType'],
  props: {
    scanner: {
      type: Object,
      required: true,
    },
    visible: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['changed', 'remove'],
  data() {
    const filters = buildFiltersFromRule(this.scanner);

    return {
      localVisible: this.visible,
      filters,
    };
  },
  computed: {
    branchExceptions() {
      return this.scanner.branch_exceptions;
    },
    branchTypes() {
      return SCAN_RESULT_BRANCH_TYPE_OPTIONS(this.namespaceType);
    },
    selectedVulnerabilitiesOperator() {
      return getSelectedVulnerabilitiesOperator(this.vulnerabilitiesAllowed);
    },
    vulnerabilitiesAllowed() {
      return enforceIntValue(this.scanner.vulnerabilities_allowed);
    },
    severityLevels() {
      return this.scanner.severity_levels?.length ? this.scanner.severity_levels : [CRITICAL, HIGH];
    },
    vulnerabilityStates() {
      const vulnerabilityStateGroups = groupVulnerabilityStatesWithDefaults(
        this.scanner.vulnerability_states,
      );
      return vulnerabilityStateGroups[NEWLY_DETECTED] || [];
    },
  },
  watch: {
    scanner(newScanner) {
      this.filters = buildFiltersFromRule(newScanner);
    },
  },
  methods: {
    handleVulnerabilitiesOperatorChange(value) {
      if (value === ANY_OPERATOR) {
        this.setVulnerabilitiesAllowed(0);
      }
    },
    setVulnerabilitiesAllowed(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.scanner, ...value });
    },
    setBranchType(value) {
      this.$emit('changed', value);
    },
    toggleCollapse() {
      this.localVisible = !this.localVisible;
    },
    removeExceptions() {
      this.$emit('changed', removeExceptionsFromScanner(this.scanner));
    },
    setRange(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
    setSeverityLevels(value) {
      this.$emit('changed', updateSeverityLevels(this.scanner, value));
    },
    setVulnerabilityStates(vulnerabilityStates) {
      this.triggerChanged({
        vulnerability_states: vulnerabilityStates,
      });
    },
  },
};
</script>

<template>
  <div>
    <scanner-header
      :title="$options.i18n.title"
      :visible="localVisible"
      show-remove-button
      @toggle="toggleCollapse"
      @remove="$emit('remove')"
    />

    <gl-collapse v-model="localVisible">
      <branch-rule-section
        :scanner="scanner"
        :branch-types="branchTypes"
        :branch-exceptions="branchExceptions"
        :vulnerabilities-allowed="vulnerabilitiesAllowed"
        :selected-operator="selectedVulnerabilitiesOperator"
        @changed="triggerChanged($event)"
        @set-branch-type="setBranchType"
        @remove-exceptions="removeExceptions"
        @operator-change="handleVulnerabilitiesOperatorChange"
        @range-input="setRange"
      />

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
        class="gl-mt-4 gl-bg-white gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <status-filter
            :filter="$options.NEWLY_DETECTED"
            :selected="vulnerabilityStates"
            :disabled="true"
            label-classes="!gl-text-base !gl-w-12 !gl-pl-0 !gl-font-bold !gl-mt-2"
            :show-remove-button="false"
            @input="setVulnerabilityStates"
          />
        </template>
      </section-layout>
    </gl-collapse>
  </div>
</template>
