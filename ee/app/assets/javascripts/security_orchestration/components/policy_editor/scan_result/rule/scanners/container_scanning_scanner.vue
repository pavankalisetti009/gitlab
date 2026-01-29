<script>
import { GlButton, GlSprintf, GlCollapse } from '@gitlab/ui';
import { s__ } from '~/locale';
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
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';
import KevFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/kev_filter.vue';
import EpssFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/epss_filter.vue';
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

export default {
  VULNERABILITIES_ALLOWED_OPERATORS,
  ATTRIBUTE_FILTERS: [
    {
      text: s__('ScanResultPolicy|New attribute'),
      value: ATTRIBUTE,
      tooltip: s__('ScanResultPolicy|Maximum of two attribute criteria allowed'),
    },
  ],
  i18n: {
    title: s__('SecurityOrchestration|Container Scanning Rule'),
    exploitTitle: s__('SecurityOrchestration|Exploit settings'),
    scanResultRuleCopy: s__(
      'SecurityOrchestration|Runs against %{branches} %{branchExceptions} and finds %{vulnerabilitiesNumber} vulnerability type that matches all the following criteria:',
    ),
    vulnerabilitiesAllowed: s__('SecurityOrchestration|vulnerabilities allowed'),
  },
  name: 'ContainerScanningScanner',
  components: {
    NumberRangeSelect,
    BranchSelection,
    BranchExceptionSelector,
    GlButton,
    GlCollapse,
    GlSprintf,
    SectionLayout,
    KevFilter,
    EpssFilter,
    AttributeFilters,
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
    return {
      localVisible: this.visible,
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
    kevFilterValue() {
      return getVulnerabilityAttribute(this.initRule, KNOWN_EXPLOITED);
    },
    epssOperator() {
      return this.initRule?.vulnerability_attributes?.[EPSS_SCORE]?.operator;
    },
    epssValue() {
      return this.initRule?.vulnerability_attributes?.[EPSS_SCORE]?.value || 0;
    },
    vulnerabilityAttributes() {
      const { vulnerability_attributes: attributes = {} } = this.initRule;
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
    setKevFilter(value) {
      this.$emit('changed', {
        ...buildVulnerabilitiesPayload(this.initRule, KNOWN_EXPLOITED, value),
      });
    },
    setEpssFilter(value) {
      this.$emit('changed', {
        ...buildVulnerabilitiesPayload(this.initRule, EPSS_SCORE, value),
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
        const { vulnerability_attributes, ...rest } = this.initRule;
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
        class="gl-mt-4 gl-bg-white gl-px-0 gl-pb-0 gl-pr-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <h5 class="gl-m-0 gl-mb-2 gl-px-5">{{ $options.i18n.exploitTitle }}</h5>

          <kev-filter :selected="kevFilterValue" @select="setKevFilter" />

          <epss-filter
            :selected-operator="epssOperator"
            :selected-value="epssValue"
            @select="setEpssFilter"
          />
        </template>
      </section-layout>

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
