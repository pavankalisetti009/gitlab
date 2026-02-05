import { nextTick } from 'vue';
import { GlCollapse } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import SecretDetectionScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/secret_detection_scanner.vue';
import BranchRuleSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/branch_rule_section.vue';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/severity_filter.vue';
import StatusFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filter.vue';
import AttributeFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/attribute_filter.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import { NEWLY_DETECTED } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('SecretDetectionScanner', () => {
  let wrapper;

  const defaultRule = {
    type: 'scan_finding',
    branches: [],
    scanners: ['secret_detection'],
    vulnerabilities_allowed: 0,
    severity_levels: [],
    vulnerability_states: [],
  };

  const createComponent = (scanner = defaultRule, options = {}) => {
    wrapper = shallowMountExtended(SecretDetectionScanner, {
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
  const findStatusFilter = () => wrapper.findComponent(StatusFilter);
  const findAttributeFilter = () => wrapper.findComponent(AttributeFilter);
  const findFilterSelector = () => wrapper.findComponent(ScanFilterSelector);

  describe('rendering', () => {
    it('renders all required components', () => {
      createComponent();

      expect(findCollapse().exists()).toBe(true);
      expect(findScannerHeader().exists()).toBe(true);
      expect(findBranchRuleSection().exists()).toBe(true);
      expect(findSeverityFilter().exists()).toBe(true);
      expect(findStatusFilter().exists()).toBe(true);
    });

    it('does not render AttributeFilter component', () => {
      createComponent();

      expect(findAttributeFilter().exists()).toBe(false);
    });

    it('does not render ScanFilterSelector component', () => {
      createComponent();

      expect(findFilterSelector().exists()).toBe(false);
    });

    it('passes scanner prop to BranchRuleSection', () => {
      createComponent();

      expect(findBranchRuleSection().props('scanner')).toEqual(defaultRule);
    });
  });

  describe('default severity levels', () => {
    it('defaults to critical and high severity levels', () => {
      createComponent();

      expect(findSeverityFilter().props('selected')).toEqual([CRITICAL, HIGH]);
    });
  });

  describe('existing rule', () => {
    const ruleWithValues = {
      ...defaultRule,
      vulnerabilities_allowed: 5,
      severity_levels: ['high', 'critical', 'medium'],
      branch_exceptions: ['main'],
      vulnerability_states: ['new_needs_triage'],
    };

    beforeEach(() => {
      createComponent(ruleWithValues);
    });

    it('passes vulnerabilities allowed value to branch rule section', () => {
      expect(findBranchRuleSection().props('vulnerabilitiesAllowed')).toBe(5);
    });

    it('passes severity levels to severity filter', () => {
      expect(findSeverityFilter().props('selected')).toEqual(['high', 'critical', 'medium']);
    });

    it('passes branch exceptions to branch rule section', () => {
      expect(findBranchRuleSection().props('branchExceptions')).toEqual(['main']);
    });

    it('renders status filter when vulnerability states are present', () => {
      expect(findStatusFilter().exists()).toBe(true);
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

    describe('status filter', () => {
      beforeEach(() => {
        createComponent({
          ...defaultRule,
          vulnerability_states: ['new_needs_triage'],
        });
      });

      it('emits changed event when status filter changes', () => {
        const payload = ['new_needs_triage'];

        findStatusFilter().vm.$emit('input', payload);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toMatchObject({
          vulnerability_states: payload,
        });
      });
    });
  });

  describe('collapse functionality', () => {
    it('is visible by default', () => {
      createComponent();

      expect(findCollapse().props('visible')).toBe(true);
    });

    it('can be collapsed', () => {
      createComponent(defaultRule, { visible: false });

      expect(findCollapse().props('visible')).toBe(false);
    });

    it('toggles collapse when header emits toggle', async () => {
      createComponent();

      expect(findCollapse().props('visible')).toBe(true);

      findScannerHeader().vm.$emit('toggle');
      await nextTick();

      expect(findCollapse().props('visible')).toBe(false);
    });
  });

  describe('status filter configuration', () => {
    it('is always rendered', () => {
      createComponent();

      expect(findStatusFilter().exists()).toBe(true);
    });

    it('sets filter to NEWLY_DETECTED and disables group selection', () => {
      createComponent({
        ...defaultRule,
        vulnerability_states: ['new_needs_triage'],
      });

      const statusFilter = findStatusFilter();
      expect(statusFilter.props('filter')).toBe(NEWLY_DETECTED);
      expect(statusFilter.props('disabled')).toBe(true);
      expect(statusFilter.props('showRemoveButton')).toBe(false);
    });

    it('passes vulnerability states to status filter', () => {
      createComponent({
        ...defaultRule,
        vulnerability_states: ['new_needs_triage', 'new_dismissed'],
      });

      const statusFilter = findStatusFilter();
      expect(statusFilter.props('selected')).toEqual(['new_needs_triage', 'new_dismissed']);
    });

    it('defaults to all options selected when no vulnerability states are set', () => {
      createComponent();

      const statusFilter = findStatusFilter();
      expect(statusFilter.props('selected')).toEqual(['new_needs_triage', 'new_dismissed']);
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
