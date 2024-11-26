<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { buildFiltersFromLicenceRule } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import BranchExceptionSelector from '../../branch_exception_selector.vue';
import ScanFilterSelector from '../../scan_filter_selector.vue';
import { SCAN_RESULT_BRANCH_TYPE_OPTIONS, BRANCH_EXCEPTIONS_KEY } from '../../constants';
import RuleMultiSelect from '../../rule_multi_select.vue';
import SectionLayout from '../../section_layout.vue';
import { getDefaultRule, LICENSE_STATES } from '../lib/rules';
import StatusFilter from './scan_filters/status_filter.vue';
import LicenseFilter from './scan_filters/license_filter.vue';
import DenyAllowList from './scan_filters/deny_allow_list.vue';
import {
  FILTERS_STATUS_INDEX,
  STATUS,
  LICENCE_FILTERS,
  DENIED,
  ALLOW_DENY,
  ALLOWED,
} from './scan_filters/constants';
import ScanTypeSelect from './scan_type_select.vue';
import BranchSelection from './branch_selection.vue';

export default {
  STATUS,
  ALLOW_DENY,
  components: {
    BranchExceptionSelector,
    DenyAllowList,
    SectionLayout,
    GlSprintf,
    LicenseFilter,
    BranchSelection,
    RuleMultiSelect,
    ScanFilterSelector,
    ScanTypeSelect,
    StatusFilter,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['namespaceType'],
  props: {
    initRule: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    licenseStatuses: s__('ScanResultPolicy|license status'),
    licenseScanResultRuleCopy: s__(
      'ScanResultPolicy|When %{scanType} in an open merge request targeting %{branches} %{branchExceptions} and the licenses match all of the following criteria:',
    ),
    tooltipFilterDisabledTitle: s__(
      'ScanResultPolicy|License scanning allows only one criteria: Status',
    ),
  },
  licenseStatuses: LICENSE_STATES,
  data() {
    const { licenses = {} } = this.initRule || {};
    const isDenied = DENIED in licenses;

    return {
      selectedFilters: buildFiltersFromLicenceRule(this.initRule),
      excludeListType: isDenied ? DENIED : ALLOWED,
    };
  },
  computed: {
    showLicenceExcludePackages() {
      return this.glFeatures.excludeLicensePackages;
    },
    showDenyAllowListFilter() {
      return this.showLicenceExcludePackages && this.isFilterSelected(this.$options.ALLOW_DENY);
    },
    filters() {
      return this.showLicenceExcludePackages
        ? LICENCE_FILTERS
        : [LICENCE_FILTERS[FILTERS_STATUS_INDEX]];
    },
    filtersTooltip() {
      return this.showLicenceExcludePackages ? '' : this.$options.i18n.tooltipFilterDisabledTitle;
    },
    branchExceptions() {
      return this.initRule.branch_exceptions;
    },
    branchTypes() {
      return SCAN_RESULT_BRANCH_TYPE_OPTIONS(this.namespaceType);
    },
    licenseStatuses: {
      get() {
        return this.initRule.license_states;
      },
      set(values) {
        this.triggerChanged({ license_states: values });
      },
    },
  },
  methods: {
    triggerChanged(value) {
      this.$emit('changed', { ...this.initRule, ...value });
    },
    setScanType(value) {
      const rule = getDefaultRule(value);
      this.$emit('set-scan-type', rule);
    },
    setBranchType(value) {
      this.$emit('changed', value);
    },
    removeExceptions() {
      const rule = { ...this.initRule };
      if (BRANCH_EXCEPTIONS_KEY in rule) {
        delete rule[BRANCH_EXCEPTIONS_KEY];
      }

      this.$emit('changed', rule);
    },
    selectExcludeListType(type) {
      this.excludeListType = type;
      this.triggerChanged({ licenses: { [type]: [] } });
    },
    isFilterSelected(filter) {
      return Boolean(this.selectedFilters[filter]);
    },
    shouldDisableFilterSelector(filter) {
      return this.isFilterSelected(filter);
    },
    selectFilter(filter, value = true) {
      this.selectedFilters = {
        ...this.selectedFilters,
        [filter]: value,
      };

      const rule = { ...this.initRule };

      if (value) {
        rule.licenses = { denied: [] };
      } else {
        delete rule.licenses;
      }

      this.$emit('changed', rule);
    },
  },
};
</script>

<template>
  <div>
    <section-layout class="gl-pb-0 gl-pr-0" :show-remove-button="false">
      <template #content>
        <section-layout class="!gl-bg-white" :show-remove-button="false">
          <template #content>
            <gl-sprintf :message="$options.i18n.licenseScanResultRuleCopy">
              <template #scanType>
                <scan-type-select :scan-type="initRule.type" @select="setScanType" />
              </template>

              <template #branches>
                <branch-selection
                  :init-rule="initRule"
                  :branch-types="branchTypes"
                  @changed="triggerChanged"
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
            </gl-sprintf>
          </template>
        </section-layout>
      </template>
    </section-layout>

    <section-layout class="gl-pr-0 gl-pt-3" :show-remove-button="false">
      <template #content>
        <status-filter
          :show-remove-button="false"
          class="!gl-bg-white md:gl-items-center"
          label-classes="!gl-text-base !gl-w-12 !gl-pl-0"
        >
          <rule-multi-select
            v-model="licenseStatuses"
            class="!gl-inline gl-align-middle"
            :item-type-name="$options.i18n.licenseStatuses"
            :items="$options.licenseStatuses"
            @error="$emit('error', $event)"
          />
        </status-filter>

        <license-filter class="!gl-bg-white" :init-rule="initRule" @changed="triggerChanged" />

        <deny-allow-list
          v-if="showDenyAllowListFilter"
          :selected="excludeListType"
          @remove="selectFilter($options.ALLOW_DENY, false)"
          @select-type="selectExcludeListType"
        />

        <scan-filter-selector
          :disabled="!showLicenceExcludePackages"
          :filters="filters"
          :tooltip-title="filtersTooltip"
          :should-disable-filter="shouldDisableFilterSelector"
          class="gl-w-full gl-bg-white"
          @select="selectFilter"
        />
      </template>
    </section-layout>
  </div>
</template>
