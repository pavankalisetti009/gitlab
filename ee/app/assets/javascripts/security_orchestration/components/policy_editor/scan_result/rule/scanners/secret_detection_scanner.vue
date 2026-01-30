<script>
import { GlButton, GlSprintf, GlCollapse } from '@gitlab/ui';
import { s__ } from '~/locale';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import {
  ANY_OPERATOR,
  BRANCH_EXCEPTIONS_KEY,
  GREATER_THAN_OPERATOR,
  SCAN_RESULT_BRANCH_TYPE_OPTIONS,
  VULNERABILITIES_ALLOWED_OPERATORS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { enforceIntValue } from 'ee/security_orchestration/components/policy_editor/utils';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/severity_filter.vue';
import StatusFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filter.vue';
import { NEWLY_DETECTED } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import {
  buildFiltersFromRule,
  groupVulnerabilityStatesWithDefaults,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';

export default {
  VULNERABILITIES_ALLOWED_OPERATORS,
  NEWLY_DETECTED,
  i18n: {
    title: s__('SecurityOrchestration|Secret Detection Scanning Rule'),
    scanResultRuleCopy: s__(
      'SecurityOrchestration|Runs against %{branches} %{branchExceptions} and finds %{vulnerabilitiesNumber} vulnerability type that matches all the following criteria:',
    ),
    vulnerabilitiesAllowed: s__('SecurityOrchestration|vulnerabilities allowed'),
  },
  name: 'SecretDetectionScanner',
  components: {
    NumberRangeSelect,
    BranchSelection,
    BranchExceptionSelector,
    GlButton,
    GlCollapse,
    GlSprintf,
    SectionLayout,
    SeverityFilter,
    StatusFilter,
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
  emits: ['changed'],
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
    collapseIcon() {
      return this.localVisible ? 'chevron-up' : 'chevron-down';
    },
    selectedVulnerabilitiesOperator() {
      return this.vulnerabilitiesAllowed === 0 ? ANY_OPERATOR : GREATER_THAN_OPERATOR;
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
      const updatedScanner = { ...this.scanner };
      if (BRANCH_EXCEPTIONS_KEY in updatedScanner) {
        delete updatedScanner[BRANCH_EXCEPTIONS_KEY];
      }

      this.$emit('changed', updatedScanner);
    },
    setRange(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
    setSeverityLevels(value) {
      const updatedScanner = { ...this.scanner };
      if (value && value.length > 0) {
        updatedScanner.severity_levels = value;
      } else {
        delete updatedScanner.severity_levels;
      }
      this.$emit('changed', updatedScanner);
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
                :init-rule="scanner"
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
