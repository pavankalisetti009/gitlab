import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecurityScanRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/security_scan_rule_builder_v2.vue';

import ScanTypeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_type_select.vue';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';
import GlobalSettings from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/global_settings.vue';
import DependencyScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/dependency_scanner.vue';
import SastScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/sast_scanner.vue';
import SecretDetectionScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/secret_detection_scanner.vue';
import ContainerScanningScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/container_scanning_scanner.vue';
import DastScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/dast_scanner.vue';
import ApiFuzzingScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/api_fuzzing_scanner.vue';
import CoverageFuzzingScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/coverage_fuzzing_scanner.vue';

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
  const findDependencyScanner = () => wrapper.findComponent(DependencyScanner);
  const findSastScanner = () => wrapper.findComponent(SastScanner);
  const findSecretDetectionScanner = () => wrapper.findComponent(SecretDetectionScanner);
  const findContainerScanningScanner = () => wrapper.findComponent(ContainerScanningScanner);
  const findDastScanner = () => wrapper.findComponent(DastScanner);
  const findApiFuzzingScanner = () => wrapper.findComponent(ApiFuzzingScanner);
  const findCoverageFuzzingScanner = () => wrapper.findComponent(CoverageFuzzingScanner);

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

    it('renders global settings with scanner prop', () => {
      expect(findGlobalSettings().exists()).toBe(true);
      expect(findGlobalSettings().props('scanner')).toEqual(defaultRule);
    });

    it('renders dependency scanner with scanner prop', () => {
      expect(findDependencyScanner().exists()).toBe(true);
      expect(findDependencyScanner().props('scanner')).toMatchObject({
        type: 'dependency_scanning',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders sast scanner with scanner prop', () => {
      expect(findSastScanner().exists()).toBe(true);
      expect(findSastScanner().props('scanner')).toMatchObject({
        type: 'sast',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders secret detection scanner with scanner prop', () => {
      expect(findSecretDetectionScanner().exists()).toBe(true);
      expect(findSecretDetectionScanner().props('scanner')).toMatchObject({
        type: 'secret_detection',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders container scanning scanner with scanner prop', () => {
      expect(findContainerScanningScanner().exists()).toBe(true);
      expect(findContainerScanningScanner().props('scanner')).toMatchObject({
        type: 'container_scanning',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders dast scanner with scanner prop', () => {
      expect(findDastScanner().exists()).toBe(true);
      expect(findDastScanner().props('scanner')).toMatchObject({
        type: 'dast',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders api fuzzing scanner with scanner prop', () => {
      expect(findApiFuzzingScanner().exists()).toBe(true);
      expect(findApiFuzzingScanner().props('scanner')).toMatchObject({
        type: 'api_fuzzing',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders coverage fuzzing scanner with scanner prop', () => {
      expect(findCoverageFuzzingScanner().exists()).toBe(true);
      expect(findCoverageFuzzingScanner().props('scanner')).toMatchObject({
        type: 'coverage_fuzzing',
        vulnerabilities_allowed: 0,
      });
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

    it('updates rule when dependency scanner changes', () => {
      const updatedScanner = {
        type: 'dependency_scanning',
        vulnerability_attributes: {
          fix_available: true,
        },
      };

      findDependencyScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when sast scanner changes', () => {
      const updatedScanner = {
        type: 'sast',
        severity_levels: ['critical', 'high'],
      };

      findSastScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when secret detection scanner changes', () => {
      const updatedScanner = {
        type: 'secret_detection',
        severity_levels: ['critical', 'high'],
        vulnerability_states: ['new_needs_triage'],
      };

      findSecretDetectionScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when container scanning scanner changes', () => {
      const updatedScanner = {
        type: 'container_scanning',
        vulnerability_attributes: {
          fix_available: true,
          false_positive: false,
        },
      };

      findContainerScanningScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when dast scanner changes', () => {
      const updatedScanner = {
        type: 'dast',
        severity_levels: ['critical', 'high'],
      };

      findDastScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when api fuzzing scanner changes', () => {
      const updatedScanner = {
        type: 'api_fuzzing',
        severity_levels: ['critical', 'high'],
      };

      findApiFuzzingScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when coverage fuzzing scanner changes', () => {
      const updatedScanner = {
        type: 'coverage_fuzzing',
        severity_levels: ['critical', 'high'],
      };

      findCoverageFuzzingScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    describe('remove scanner', () => {
      it.each`
        scannerName             | scannerType              | findMethod
        ${'dependency'}         | ${'dependency_scanning'} | ${findDependencyScanner}
        ${'sast'}               | ${'sast'}                | ${findSastScanner}
        ${'secret detection'}   | ${'secret_detection'}    | ${findSecretDetectionScanner}
        ${'container scanning'} | ${'container_scanning'}  | ${findContainerScanningScanner}
        ${'dast'}               | ${'dast'}                | ${findDastScanner}
        ${'api fuzzing'}        | ${'api_fuzzing'}         | ${findApiFuzzingScanner}
        ${'coverage fuzzing'}   | ${'coverage_fuzzing'}    | ${findCoverageFuzzingScanner}
      `(
        'removes $scannerName scanner when remove event is emitted',
        ({ scannerType, findMethod }) => {
          createComponent();

          findMethod().vm.$emit('remove');

          const emittedRule = wrapper.emitted('changed')[0][0];
          expect(emittedRule.scanners).not.toEqual(
            expect.arrayContaining([expect.objectContaining({ type: scannerType })]),
          );
        },
      );

      it('emits updated scanners array when a scanner is removed', () => {
        createComponent({
          ...defaultRule,
          scanners: ['sast', 'dast'],
        });

        findSastScanner().vm.$emit('remove');

        const emittedRule = wrapper.emitted('changed')[0][0];
        expect(emittedRule.scanners).toEqual([expect.objectContaining({ type: 'dast' })]);
      });
    });
  });
});
