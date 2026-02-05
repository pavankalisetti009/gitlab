<script>
import { GlCollapse } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import {
  ANY_OPERATOR,
  SCAN_RESULT_BRANCH_TYPE_OPTIONS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { enforceIntValue } from 'ee/security_orchestration/components/policy_editor/utils';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import AttributeFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/attribute_filters.vue';
import {
  KNOWN_EXPLOITED,
  EPSS_SCORE,
  FIX_AVAILABLE,
  FALSE_POSITIVE,
  ATTRIBUTE,
  VULNERABILITY_ATTRIBUTES,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import {
  buildVulnerabilitiesPayload,
  getVulnerabilityAttribute,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/utils';
import {
  getSelectedVulnerabilitiesOperator,
  removeExceptionsFromScanner,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';
import BranchRuleSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/branch_rule_section.vue';
import ExploitSettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/exploit_settings_section.vue';

export default {
  ATTRIBUTE_FILTERS: [
    {
      text: s__('ScanResultPolicy|New attribute'),
      value: ATTRIBUTE,
      tooltip: s__('ScanResultPolicy|Maximum of two attribute criteria allowed'),
    },
  ],
  i18n: {
    title: s__('SecurityOrchestration|Container Scanning Rule'),
  },
  name: 'ContainerScanningScanner',
  components: {
    GlCollapse,
    SectionLayout,
    AttributeFilters,
    ScanFilterSelector,
    ScannerHeader,
    BranchRuleSection,
    ExploitSettingsSection,
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
    return {
      localVisible: this.visible,
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
    kevFilterValue() {
      return getVulnerabilityAttribute(this.scanner, KNOWN_EXPLOITED);
    },
    epssOperator() {
      return this.scanner?.vulnerability_attributes?.[EPSS_SCORE]?.operator;
    },
    epssValue() {
      return this.scanner?.vulnerability_attributes?.[EPSS_SCORE]?.value || 0;
    },
    vulnerabilityAttributes() {
      const { vulnerability_attributes: attributes = {} } = this.scanner;
      const { [KNOWN_EXPLOITED]: kevFilter, [EPSS_SCORE]: epssFilter, ...rest } = attributes;

      if (Object.keys(rest).length === 0) {
        return {
          [FIX_AVAILABLE]: true,
          [FALSE_POSITIVE]: false,
        };
      }

      return rest;
    },
    isAttributeFilterSelected() {
      return Object.keys(this.vulnerabilityAttributes).some((key) =>
        [FIX_AVAILABLE, FALSE_POSITIVE].includes(key),
      );
    },
    filters() {
      const vulnerabilityAttributes = this.vulnerabilityAttributes || {};
      return {
        [FIX_AVAILABLE]: vulnerabilityAttributes[FIX_AVAILABLE] !== undefined,
        [FALSE_POSITIVE]: vulnerabilityAttributes[FALSE_POSITIVE] !== undefined,
        [ATTRIBUTE]: Boolean(
          vulnerabilityAttributes[FIX_AVAILABLE] !== undefined &&
            vulnerabilityAttributes[FALSE_POSITIVE] !== undefined,
        ),
      };
    },
    isAttributeSelectorDisabled() {
      return Object.keys(this.vulnerabilityAttributes).length >= VULNERABILITY_ATTRIBUTES.length;
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
    setKevFilter(value) {
      this.$emit('changed', {
        ...buildVulnerabilitiesPayload(this.scanner, KNOWN_EXPLOITED, value),
      });
    },
    setEpssFilter(value) {
      this.$emit('changed', {
        ...buildVulnerabilitiesPayload(this.scanner, EPSS_SCORE, value),
      });
    },
    setVulnerabilityAttributes(value) {
      const hasAttributes = Object.keys(value).length > 0;

      const kevAttribute = this.kevFilterValue ? { [KNOWN_EXPLOITED]: this.kevFilterValue } : {};
      const epssAttribute =
        this.epssOperator && this.epssValue
          ? { [EPSS_SCORE]: { operator: this.epssOperator, value: this.epssValue } }
          : {};

      const vulnerabilityAttributes = {
        ...kevAttribute,
        ...epssAttribute,
        ...(hasAttributes ? value : {}),
      };

      if (Object.keys(vulnerabilityAttributes).length === 0) {
        const { vulnerability_attributes, ...rest } = this.scanner;
        this.$emit('changed', rest);
      } else {
        this.triggerChanged({ vulnerability_attributes: vulnerabilityAttributes });
      }
    },
    removeAttributesFilter(attribute) {
      const { [attribute]: deletedAttribute, ...otherAttributes } = this.vulnerabilityAttributes;
      this.setVulnerabilityAttributes(otherAttributes);
    },
    selectFilter() {
      const attributeKey =
        Object.keys(this.vulnerabilityAttributes)[0] === FIX_AVAILABLE
          ? FALSE_POSITIVE
          : FIX_AVAILABLE;
      this.setVulnerabilityAttributes({
        ...this.vulnerabilityAttributes,
        [attributeKey]: true,
      });
    },
    shouldDisableFilter(filter) {
      if (filter === ATTRIBUTE) {
        return this.isAttributeSelectorDisabled;
      }
      return false;
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

      <exploit-settings-section
        :kev-filter-value="kevFilterValue"
        :epss-operator="epssOperator"
        :epss-value="epssValue"
        @kev-change="setKevFilter"
        @epss-change="setEpssFilter"
      />

      <section-layout
        v-if="isAttributeFilterSelected"
        class="gl-mt-4 gl-bg-white gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <attribute-filters
            :selected="vulnerabilityAttributes"
            @remove="removeAttributesFilter"
            @input="setVulnerabilityAttributes"
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
              :filters="$options.ATTRIBUTE_FILTERS"
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
