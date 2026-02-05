import { nextTick } from 'vue';
import { GlCollapse } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SastScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/sast_scanner.vue';
import BranchRuleSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/branch_rule_section.vue';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/severity_filter.vue';
import StatusFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filters.vue';
import AttributeFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/attribute_filter.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import {
  FALSE_POSITIVE,
  STATUS,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('SastScanner', () => {
  let wrapper;

  const defaultRule = {
    type: 'scan_finding',
    branches: [],
    scanners: ['sast'],
    vulnerabilities_allowed: 0,
    severity_levels: [],
    vulnerability_states: [],
  };

  const createComponent = (scanner = defaultRule, options = {}) => {
    wrapper = shallowMountExtended(SastScanner, {
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
  const findSeverityFilter = () => wrapper.findComponent(SeverityFilter);
  const findStatusFilters = () => wrapper.findComponent(StatusFilters);
  const findAttributeFilter = () => wrapper.findComponent(AttributeFilter);
  const findFilterSelector = () => wrapper.findComponent(ScanFilterSelector);

  describe('rendering', () => {
    it('renders all components correctly', () => {
      createComponent();

      expect(findCollapse().exists()).toBe(true);
      expect(findScannerHeader().exists()).toBe(true);
      expect(findBranchRuleSection().exists()).toBe(true);
      expect(findSeverityFilter().exists()).toBe(true);
      expect(findAttributeFilter().exists()).toBe(true);
      expect(findAttributeFilter().props('attribute')).toBe(FALSE_POSITIVE);
      expect(findAttributeFilter().props('operatorValue')).toBe(false);
      expect(findAttributeFilter().props('disabled')).toBe(true);
      expect(findAttributeFilter().props('showRemoveButton')).toBe(false);
      expect(findFilterSelector().exists()).toBe(true);
    });

    it('passes scanner prop to BranchRuleSection', () => {
      createComponent();

      expect(findBranchRuleSection().props('scanner')).toEqual(defaultRule);
    });
  });

  describe('existing rule', () => {
    const ruleWithValues = {
      ...defaultRule,
      vulnerabilities_allowed: 5,
      severity_levels: ['high', 'critical'],
      branch_exceptions: ['main'],
      vulnerability_states: ['detected', 'confirmed'],
      vulnerability_attributes: {
        [FALSE_POSITIVE]: true,
      },
    };

    beforeEach(() => {
      createComponent(ruleWithValues);
    });

    it('passes vulnerabilities allowed value to branch rule section', () => {
      expect(findBranchRuleSection().props('vulnerabilitiesAllowed')).toBe(5);
    });

    it('passes severity levels to severity filter', () => {
      expect(findSeverityFilter().props('selected')).toEqual(['high', 'critical']);
    });

    it('passes branch exceptions to branch rule section', () => {
      expect(findBranchRuleSection().props('branchExceptions')).toEqual(['main']);
    });

    it('renders status filters when vulnerability states are present', () => {
      expect(findStatusFilters().exists()).toBe(true);
    });

    it('renders attribute filter with false_positive attribute', () => {
      expect(findAttributeFilter().exists()).toBe(true);
      expect(findAttributeFilter().props('attribute')).toBe(FALSE_POSITIVE);
      expect(findAttributeFilter().props('operatorValue')).toBe(true);
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

    it('emits changed event when severity levels change', () => {
      const severityLevels = ['critical'];

      findSeverityFilter().vm.$emit('input', severityLevels);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toMatchObject({
        severity_levels: severityLevels,
      });
    });

    describe('status filters', () => {
      beforeEach(() => {
        createComponent({
          ...defaultRule,
          vulnerability_states: ['detected'],
        });
      });

      it('emits changed event when status filters change', () => {
        const payload = { [NEWLY_DETECTED]: ['new_needs_triage'] };

        findStatusFilters().vm.$emit('input', payload);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toHaveProperty('vulnerability_states');
      });

      it('emits changed event when status group changes', () => {
        const payload = {
          [NEWLY_DETECTED]: ['new_needs_triage'],
          [PREVIOUSLY_EXISTING]: null,
        };

        findStatusFilters().vm.$emit('change-status-group', payload);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toHaveProperty('vulnerability_states');
      });

      it('removes status filter when remove is triggered', () => {
        findStatusFilters().vm.$emit('remove', NEWLY_DETECTED);

        expect(wrapper.emitted('changed')).toHaveLength(1);
      });
    });

    describe('attribute filter', () => {
      beforeEach(() => {
        createComponent({
          ...defaultRule,
          vulnerability_attributes: {
            [FALSE_POSITIVE]: true,
          },
        });
      });

      it('emits changed event when attribute filter value changes', () => {
        findAttributeFilter().vm.$emit('input', false);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toMatchObject({
          vulnerability_attributes: {
            [FALSE_POSITIVE]: false,
          },
        });
      });
    });
  });

  describe('selecting filter', () => {
    beforeEach(() => {
      createComponent();
    });

    it('adds new status filter when selected', async () => {
      expect(findFilterSelector().props('selected')[NEWLY_DETECTED]).toBe(true);

      findFilterSelector().vm.$emit('select', STATUS);
      await nextTick();

      expect(findFilterSelector().props('selected')[PREVIOUSLY_EXISTING]).toBe(true);
    });
  });

  describe('filter selector disabled state', () => {
    it('is not disabled when no filters are selected', () => {
      createComponent();

      expect(findFilterSelector().props('shouldDisableFilter')(STATUS)).toBe(false);
    });

    it('status is not disabled when one status is selected', () => {
      createComponent({
        ...defaultRule,
        vulnerability_states: ['detected'],
      });

      expect(findFilterSelector().props('shouldDisableFilter')(STATUS)).toBe(false);
    });

    it('status is disabled when both statuses are selected', () => {
      createComponent({
        ...defaultRule,
        vulnerability_states: ['new_needs_triage', 'detected'],
      });

      expect(findFilterSelector().props('shouldDisableFilter')(STATUS)).toBe(true);
    });
  });

  describe('scan filter selector', () => {
    it('passes correct filter state when no filters are selected', () => {
      createComponent();

      expect(findFilterSelector().props('selected')).toMatchObject({
        [STATUS]: false,
      });
    });

    it('passes correct filter state when status filter is selected', () => {
      createComponent();

      expect(findFilterSelector().props('selected')[STATUS]).toBe(false);
    });

    it('only shows STATUS filter option', () => {
      createComponent();

      expect(findFilterSelector().props('filters')).toHaveLength(1);
      expect(findFilterSelector().props('filters')[0].value).toBe(STATUS);
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
