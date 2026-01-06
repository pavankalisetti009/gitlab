<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { REPORT_TYPES_DEFAULT, REPORT_TYPES_DEFAULT_KEYS } from 'ee/security_dashboard/constants';
import {
  ANY_OPERATOR,
  GREATER_THAN_OPERATOR,
  BRANCH_EXCEPTIONS_KEY,
  SCAN_RESULT_BRANCH_TYPE_OPTIONS,
  VULNERABILITIES_ALLOWED_OPERATORS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import { enforceIntValue } from 'ee/security_orchestration/components/policy_editor/utils';
import { getDefaultRule } from '../lib';
import ScanTypeSelect from './scan_type_select.vue';
import NumberRangeSelect from './number_range_select.vue';
import GlobalSettings from './scanners/global_settings.vue';
import { selectEmptyArrayWhenAllSelected } from './scanners/utils';

export default {
  REPORT_TYPES_DEFAULT,
  VULNERABILITIES_ALLOWED_OPERATORS,
  i18n: {
    scanners: s__('ScanResultPolicy|scanners'),
    scanResultRuleCopy: s__(
      'ScanResultPolicy|When a %{scanType} with %{scanners} runs against %{branches} %{branchExceptions} and finds %{vulnerabilitiesNumber} vulnerability type that matches all the following criteria:',
    ),
    vulnerabilitiesAllowed: s__('ScanResultPolicy|vulnerabilities allowed'),
  },
  name: 'SecurityScanRuleBuilder',
  components: {
    NumberRangeSelect,
    BranchExceptionSelector,
    BranchSelection,
    GlobalSettings,
    GlSprintf,
    RuleMultiSelect,
    ScanTypeSelect,
    SectionLayout,
  },
  inject: ['namespaceType'],
  props: {
    initRule: {
      type: Object,
      required: true,
    },
  },
  emits: ['set-scan-type', 'changed', 'error'],
  computed: {
    branchExceptions() {
      return this.initRule.branch_exceptions;
    },
    branchTypes() {
      return SCAN_RESULT_BRANCH_TYPE_OPTIONS(this.namespaceType);
    },
    scanners() {
      return this.initRule.scanners.length === 0
        ? Object.keys(REPORT_TYPES_DEFAULT)
        : this.initRule.scanners;
    },
    selectedVulnerabilitiesOperator() {
      return this.vulnerabilitiesAllowed === 0 ? ANY_OPERATOR : GREATER_THAN_OPERATOR;
    },
    vulnerabilitiesAllowed() {
      return enforceIntValue(this.initRule.vulnerabilities_allowed);
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
    setScanType(value) {
      const rule = getDefaultRule(value);
      this.$emit('set-scan-type', rule);
    },
    setBranchType(value) {
      this.$emit('changed', value);
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.initRule, ...value });
    },
    updateGlobalSettings(rule) {
      this.$emit('changed', rule);
    },
    removeExceptions() {
      const rule = { ...this.initRule };
      if (BRANCH_EXCEPTIONS_KEY in rule) {
        delete rule[BRANCH_EXCEPTIONS_KEY];
      }

      this.$emit('changed', rule);
    },
    setScanners(values) {
      this.triggerChanged({
        scanners: selectEmptyArrayWhenAllSelected(values, REPORT_TYPES_DEFAULT_KEYS.length),
      });
    },
    setRange(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
  },
};
</script>

<template>
  <section-layout class="gl-pr-0" :show-remove-button="false" @changed="$emit('changed', $event)">
    <template #content>
      <section-layout :show-remove-button="false">
        <template #content>
          <gl-sprintf :message="$options.i18n.scanResultRuleCopy">
            <template #scanType>
              <scan-type-select :scan-type="initRule.type" @select="setScanType" />
            </template>

            <template #scanners>
              <rule-multi-select
                :value="scanners"
                class="!gl-inline gl-align-middle"
                :item-type-name="$options.i18n.scanners"
                :items="$options.REPORT_TYPES_DEFAULT"
                data-testid="scanners-select"
                @error="$emit('error', $event)"
                @input="setScanners"
              />
            </template>

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

      <div class="gl-w-full gl-rounded-base gl-bg-white gl-p-4">
        <global-settings :init-rule="initRule" @changed="updateGlobalSettings" />
      </div>
    </template>
  </section-layout>
</template>
