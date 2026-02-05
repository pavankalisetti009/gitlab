import { nextTick } from 'vue';
import { GlCollapse } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ContainerScanningScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/container_scanning_scanner.vue';
import BranchRuleSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/branch_rule_section.vue';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';
import ExploitSettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/exploit_settings_section.vue';
import AttributeFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/attribute_filters.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import {
  FIX_AVAILABLE,
  FALSE_POSITIVE,
  KNOWN_EXPLOITED,
  EPSS_SCORE,
  ATTRIBUTE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('ContainerScanningScanner', () => {
  let wrapper;

  const defaultRule = {
    type: 'scan_finding',
    branches: [],
    scanners: ['container_scanning'],
    vulnerabilities_allowed: 0,
    severity_levels: [],
    vulnerability_states: [],
  };

  const createComponent = (scanner = defaultRule, options = {}) => {
    wrapper = shallowMountExtended(ContainerScanningScanner, {
      propsData: {
        scanner,
        ...options,
      },
      provide: {
        namespaceType: 'project',
      },
    });
  };

  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findScannerHeader = () => wrapper.findComponent(ScannerHeader);
  const findBranchRuleSection = () => wrapper.findComponent(BranchRuleSection);
  const findExploitSettingsSection = () => wrapper.findComponent(ExploitSettingsSection);
  const findAttributeFilters = () => wrapper.findComponent(AttributeFilters);
  const findFilterSelector = () => wrapper.findComponent(ScanFilterSelector);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders collapse component', () => {
      expect(findCollapse().exists()).toBe(true);
    });

    it('renders scanner header', () => {
      expect(findScannerHeader().exists()).toBe(true);
    });

    it('renders branch rule section', () => {
      expect(findBranchRuleSection().exists()).toBe(true);
    });

    it('renders exploit settings section', () => {
      expect(findExploitSettingsSection().exists()).toBe(true);
    });

    it('renders attribute filters with default values', () => {
      expect(findAttributeFilters().exists()).toBe(true);
      expect(findAttributeFilters().props('selected')).toEqual({
        [FIX_AVAILABLE]: true,
        [FALSE_POSITIVE]: false,
      });
    });

    it('renders scan filter selector', () => {
      expect(findFilterSelector().exists()).toBe(true);
    });

    it('passes scanner prop to BranchRuleSection', () => {
      expect(findBranchRuleSection().props('scanner')).toEqual(defaultRule);
    });
  });

  describe('default attribute filters', () => {
    it('has both attribute filters selected by default', () => {
      createComponent();

      expect(findAttributeFilters().exists()).toBe(true);
      expect(findAttributeFilters().props('selected')).toEqual({
        [FIX_AVAILABLE]: true,
        [FALSE_POSITIVE]: false,
      });
    });
  });

  describe('visibility prop', () => {
    it('is visible by default', () => {
      createComponent();

      expect(wrapper.props('visible')).toBe(true);
    });

    it('can be initialized as hidden', () => {
      createComponent(defaultRule, { visible: false });

      expect(wrapper.props('visible')).toBe(false);
    });
  });

  describe('existing rule', () => {
    const ruleWithValues = {
      ...defaultRule,
      vulnerabilities_allowed: 5,
      branch_exceptions: ['main'],
      vulnerability_attributes: {
        [KNOWN_EXPLOITED]: true,
        [EPSS_SCORE]: { operator: 'greater_than', value: 0.5 },
        [FIX_AVAILABLE]: false,
        [FALSE_POSITIVE]: true,
      },
    };

    beforeEach(() => {
      createComponent(ruleWithValues);
    });

    it('passes vulnerabilities allowed value to branch rule section', () => {
      expect(findBranchRuleSection().props('vulnerabilitiesAllowed')).toBe(5);
    });

    it('passes branch exceptions to branch rule section', () => {
      expect(findBranchRuleSection().props('branchExceptions')).toEqual(['main']);
    });

    it('passes KEV filter value to exploit settings section', () => {
      expect(findExploitSettingsSection().props('kevFilterValue')).toBe(true);
    });

    it('passes EPSS filter values to exploit settings section', () => {
      expect(findExploitSettingsSection().props('epssOperator')).toBe('greater_than');
      expect(findExploitSettingsSection().props('epssValue')).toBe(0.5);
    });

    it('renders attribute filters when attributes are selected', () => {
      expect(findAttributeFilters().exists()).toBe(true);
      expect(findAttributeFilters().props('selected')).toEqual({
        [FIX_AVAILABLE]: false,
        [FALSE_POSITIVE]: true,
      });
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits changed event when branch rule section emits changed', () => {
      const payload = { branches: ['main'] };

      findBranchRuleSection().vm.$emit('changed', payload);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toMatchObject(payload);
    });

    it('emits changed event when branch exceptions are removed', () => {
      createComponent({
        ...defaultRule,
        branch_exceptions: ['main'],
      });

      findBranchRuleSection().vm.$emit('remove-exceptions');

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).not.toHaveProperty('branch_exceptions');
    });

    it('emits changed event when vulnerabilities allowed changes', () => {
      findBranchRuleSection().vm.$emit('range-input', 10);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toMatchObject({
        vulnerabilities_allowed: 10,
      });
    });

    it('emits changed event when KEV filter changes', () => {
      findExploitSettingsSection().vm.$emit('kev-change', true);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toHaveProperty('vulnerability_attributes');
      expect(wrapper.emitted('changed')[0][0].vulnerability_attributes).toHaveProperty(
        KNOWN_EXPLOITED,
        true,
      );
    });

    it('emits changed event when EPSS filter changes', () => {
      const epssValue = { operator: 'less_than', value: 0.3 };

      findExploitSettingsSection().vm.$emit('epss-change', epssValue);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toHaveProperty('vulnerability_attributes');
      expect(wrapper.emitted('changed')[0][0].vulnerability_attributes).toHaveProperty(
        EPSS_SCORE,
        epssValue,
      );
    });

    describe('attribute filters', () => {
      it('emits changed event when attribute filters change', () => {
        const payload = { [FIX_AVAILABLE]: true, [FALSE_POSITIVE]: false };

        findAttributeFilters().vm.$emit('input', payload);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toHaveProperty('vulnerability_attributes');
      });

      it('removes attribute filter when remove is triggered', () => {
        findAttributeFilters().vm.$emit('remove', FIX_AVAILABLE);

        expect(wrapper.emitted('changed')).toHaveLength(1);
      });
    });
  });

  describe('selecting filter', () => {
    it('adds the opposite attribute when one is already selected', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [FIX_AVAILABLE]: true,
        },
      });

      findFilterSelector().vm.$emit('select');

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0].vulnerability_attributes).toHaveProperty(
        FALSE_POSITIVE,
        true,
      );
    });
  });

  describe('filter selector disabled state', () => {
    it('is disabled by default with both attributes selected', () => {
      createComponent();

      expect(findFilterSelector().props('shouldDisableFilter')(ATTRIBUTE)).toBe(true);
    });

    it('is not disabled when one attribute is selected', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [FIX_AVAILABLE]: true,
        },
      });

      expect(findFilterSelector().props('shouldDisableFilter')(ATTRIBUTE)).toBe(false);
    });
  });

  describe('scan filter selector', () => {
    it('passes correct filter state with default attributes', () => {
      createComponent();

      expect(findFilterSelector().props('selected')).toEqual({
        [FIX_AVAILABLE]: true,
        [FALSE_POSITIVE]: true,
        [ATTRIBUTE]: true,
      });
    });

    it('passes correct filter state when one attribute is selected', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [FIX_AVAILABLE]: true,
        },
      });

      expect(findFilterSelector().props('selected')).toEqual({
        [FIX_AVAILABLE]: true,
        [FALSE_POSITIVE]: false,
        [ATTRIBUTE]: false,
      });
    });
  });

  describe('collapse behavior', () => {
    it('toggles collapse when header emits toggle', async () => {
      createComponent();

      expect(findCollapse().props('visible')).toBe(true);

      findScannerHeader().vm.$emit('toggle');
      await nextTick();

      expect(findCollapse().props('visible')).toBe(false);
    });
  });

  describe('remove scanner', () => {
    it('passes showRemoveButton prop to scanner header', () => {
      createComponent();

      expect(findScannerHeader().props('showRemoveButton')).toBe(true);
    });

    it('emits remove event when scanner header emits remove', () => {
      createComponent();

      findScannerHeader().vm.$emit('remove');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });
  });
});
