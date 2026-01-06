import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecurityScanRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/security_scan_rule_builder_v2.vue';

import ScanTypeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_type_select.vue';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';
import GlobalSettings from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/global_settings.vue';

import { REPORT_TYPES_DEFAULT_KEYS } from 'ee/security_dashboard/constants';

describe('SecurityScanRuleBuilder', () => {
  let wrapper;

  const defaultRule = {
    type: 'scan_finding',
    scanners: [],
    vulnerabilities_allowed: 0,
    branch_exceptions: [],
  };

  const createComponent = (initRule = defaultRule) => {
    wrapper = shallowMountExtended(SecurityScanRuleBuilder, {
      propsData: {
        initRule,
      },
      provide: {
        namespaceType: 'project',
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findScanTypeSelect = () => wrapper.findComponent(ScanTypeSelect);
  const findScannersSelect = () => wrapper.findComponent(RuleMultiSelect);
  const findBranchSelection = () => wrapper.findComponent(BranchSelection);
  const findBranchExceptionSelector = () => wrapper.findComponent(BranchExceptionSelector);
  const findNumberRangeSelect = () => wrapper.findComponent(NumberRangeSelect);
  const findGlobalSettings = () => wrapper.findComponent(GlobalSettings);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders scan type select', () => {
      expect(findScanTypeSelect().exists()).toBe(true);
    });

    it('renders scanners multi select', () => {
      expect(findScannersSelect().exists()).toBe(true);
    });

    it('renders branch selection', () => {
      expect(findBranchSelection().exists()).toBe(true);
    });

    it('renders branch exception selector', () => {
      expect(findBranchExceptionSelector().exists()).toBe(true);
    });

    it('renders vulnerabilities number selector', () => {
      expect(findNumberRangeSelect().exists()).toBe(true);
    });

    it('renders global settings', () => {
      expect(findGlobalSettings().exists()).toBe(true);
    });
  });

  describe('selected values', () => {
    it('returns all scanners when none are selected', () => {
      createComponent({
        ...defaultRule,
        scanners: [],
      });

      expect(findScannersSelect().props('value')).toEqual(REPORT_TYPES_DEFAULT_KEYS);
    });

    it('returns selected scanners when provided', () => {
      const scanners = ['sast', 'dependency_scanning'];

      createComponent({
        ...defaultRule,
        scanners,
      });

      expect(findScannersSelect().props('value')).toEqual(scanners);
    });

    it('renders existing branch types', () => {
      const newRule = {
        ...defaultRule,
        branchType: 'default',
      };

      createComponent(newRule);

      expect(findBranchSelection().props('initRule')).toEqual(newRule);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits set-scan-type when scan type changes', () => {
      const newRule = { type: 'license_finding' };

      findScanTypeSelect().vm.$emit('select', 'license_finding');

      expect(wrapper.emitted('set-scan-type')).toHaveLength(1);
      expect(wrapper.emitted('set-scan-type')[0][0]).toMatchObject(newRule);
    });

    it('updates scanners when scanners selection changes', () => {
      const scanners = ['sast'];

      findScannersSelect().vm.$emit('input', scanners);

      expect(wrapper.emitted('changed')).toEqual([[{ ...defaultRule, scanners }]]);
    });

    it('updates vulnerabilities allowed range', () => {
      const value = 5;

      findNumberRangeSelect().vm.$emit('input', value);

      expect(wrapper.emitted('changed')).toEqual([
        [{ ...defaultRule, vulnerabilities_allowed: value }],
      ]);
    });

    it('updates rule when branch selection changes', () => {
      const payload = { branches: ['main'] };

      findBranchSelection().vm.$emit('changed', payload);

      expect(wrapper.emitted('changed')).toEqual([[{ ...defaultRule, ...payload }]]);
    });

    it('removes branch exceptions when remove is triggered', () => {
      createComponent({
        ...defaultRule,
        branch_exceptions: ['dev'],
      });

      findBranchExceptionSelector().vm.$emit('remove');

      expect(wrapper.emitted('changed')[0][0]).not.toHaveProperty('branch_exceptions');
    });

    it('updates global settings', () => {
      const updatedRule = {
        ...defaultRule,
        severity_levels: ['high'],
      };

      findGlobalSettings().vm.$emit('changed', updatedRule);

      expect(wrapper.emitted('changed')).toEqual([[updatedRule]]);
    });
  });
});
