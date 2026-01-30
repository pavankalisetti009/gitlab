import { nextTick } from 'vue';
import { GlCollapse, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CoverageFuzzingScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/coverage_fuzzing_scanner.vue';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/severity_filter.vue';
import StatusFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filters.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import {
  STATUS,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('CoverageFuzzingScanner', () => {
  let wrapper;

  const defaultRule = {
    type: 'scan_finding',
    branches: [],
    scanners: ['coverage_fuzzing'],
    vulnerabilities_allowed: 0,
    severity_levels: [],
    vulnerability_states: [],
  };

  const createComponent = (scanner = defaultRule, options = {}) => {
    wrapper = shallowMountExtended(CoverageFuzzingScanner, {
      propsData: {
        scanner,
        ...options,
      },
      provide: {
        namespaceType: 'project',
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findBranchSelection = () => wrapper.findComponent(BranchSelection);
  const findBranchExceptionSelector = () => wrapper.findComponent(BranchExceptionSelector);
  const findNumberRangeSelect = () => wrapper.findComponent(NumberRangeSelect);
  const findSeverityFilter = () => wrapper.findComponent(SeverityFilter);
  const findStatusFilters = () => wrapper.findComponent(StatusFilters);
  const findFilterSelector = () => wrapper.findComponent(ScanFilterSelector);

  describe('rendering', () => {
    it('renders all components correctly', () => {
      createComponent();

      expect(findCollapse().exists()).toBe(true);
      expect(findBranchSelection().exists()).toBe(true);
      expect(findBranchExceptionSelector().exists()).toBe(true);
      expect(findNumberRangeSelect().exists()).toBe(true);
      expect(findSeverityFilter().exists()).toBe(true);
      expect(findFilterSelector().exists()).toBe(true);
    });
  });

  describe('existing rule', () => {
    beforeEach(() => {
      createComponent({
        ...defaultRule,
        vulnerabilities_allowed: 5,
        severity_levels: ['high', 'critical'],
        branch_exceptions: ['main'],
        vulnerability_states: ['detected', 'confirmed'],
      });
    });

    it('passes vulnerabilities allowed value to number range select', () => {
      expect(findNumberRangeSelect().props('value')).toBe(5);
    });

    it('passes severity levels to severity filter', () => {
      expect(findSeverityFilter().props('selected')).toEqual(['high', 'critical']);
    });

    it('passes branch exceptions to branch exception selector', () => {
      expect(findBranchExceptionSelector().props('selectedExceptions')).toEqual(['main']);
    });

    it('renders status filters when vulnerability states are present', () => {
      expect(findStatusFilters().exists()).toBe(true);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits changed event when branch selection changes', () => {
      const payload = { branches: ['main'] };

      findBranchSelection().vm.$emit('changed', payload);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toMatchObject(payload);
    });

    it('emits changed event when branch exceptions are removed', () => {
      createComponent({
        ...defaultRule,
        branch_exceptions: ['main'],
      });

      findBranchExceptionSelector().vm.$emit('remove');

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).not.toHaveProperty('branch_exceptions');
    });

    it('emits changed event when vulnerabilities allowed changes', () => {
      findNumberRangeSelect().vm.$emit('input', 10);

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
});
