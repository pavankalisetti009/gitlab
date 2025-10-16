import { GlAlert, GlFormGroup, GlFormRadioGroup, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { helpPagePath } from '~/helpers/help_page_helper';
import EnforcementType from 'ee/security_orchestration/components/policy_editor/scan_result/enforcement/enforcement_type.vue';

describe('EnforcementType', () => {
  let wrapper;

  const defaultProps = {
    enforcement: 'enforce',
    hasLegacyWarnAction: false,
    isWarnMode: false,
  };

  const factory = (propsData = {}) => {
    wrapper = shallowMountExtended(EnforcementType, {
      propsData: {
        ...defaultProps,
        ...propsData,
      },
      stubs: { GlSprintf },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLink = () => wrapper.findComponent(GlLink);

  describe('rendering', () => {
    beforeEach(() => {
      factory();
    });

    it('renders the form group with correct label', () => {
      expect(findFormGroup().exists()).toBe(true);
      expect(findFormGroup().attributes('label')).toBe('Policy enforcement');
    });

    it('renders the radio group with correct options and checked value', () => {
      expect(findRadioGroup().exists()).toBe(true);
      expect(findRadioGroup().props('options')).toEqual([
        { disabled: false, text: 'Warn mode', value: 'warn' },
        { disabled: false, text: 'Strictly enforced', value: 'enforce' },
      ]);
      expect(findRadioGroup().attributes('checked')).toBe('enforce');
    });

    it('does not render alert by default', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('enforcement prop', () => {
    it('displays warn mode when enforcement is warn', () => {
      factory({ enforcement: 'warn' });

      expect(findRadioGroup().attributes('checked')).toBe('warn');
    });

    it('displays enforce mode when enforcement is enforce', () => {
      factory({ enforcement: 'enforce' });

      expect(findRadioGroup().attributes('checked')).toBe('enforce');
    });
  });

  describe('disabled prop', () => {
    it('disables options', () => {
      factory({ disabledEnforcementOptions: ['warn'] });

      expect(findRadioGroup().props('options')).toEqual([
        { disabled: true, text: 'Warn mode', value: 'warn' },
        { disabled: false, text: 'Strictly enforced', value: 'enforce' },
      ]);
    });
  });

  describe('alert display', () => {
    it('shows alert when isWarnMode is true', () => {
      factory({ isWarnMode: true });

      const alert = findAlert();
      expect(findAlert().exists()).toBe(true);
      expect(alert.text()).toBe(
        'In warn mode, project approval settings are not overridden by policy and violations are reported, but fixes for the violations are not mandatory. License scanning is not supported in warn mode. Learn more',
      );
      const link = findLink();
      const expectedPath = helpPagePath(
        'user/application_security/policies/merge_request_approval_policies',
        {
          anchor: 'warn-mode',
        },
      );

      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe(expectedPath);
      expect(link.attributes('target')).toBe('_blank');
    });

    it('shows alert when hasLegacyWarnAction is true', () => {
      factory({ hasLegacyWarnAction: true });
      const alert = findAlert();
      expect(findAlert().exists()).toBe(true);
      expect(alert.text()).toBe(
        'This policy was previously in warn mode, which was an experimental feature. Due to changes in the feature, warn mode is now disabled. To enable the new warn mode setting, update this property.',
      );
    });

    it('shows alert when both isWarnMode and hasLegacyWarnAction are true', () => {
      factory({ isWarnMode: true, hasLegacyWarnAction: true });

      const alert = findAlert();
      expect(findAlert().exists()).toBe(true);
      expect(alert.text()).toContain(
        'In warn mode, project approval settings are not overridden by policy and violations are reported',
      );
    });

    it('does not show alert when both isWarnMode and hasLegacyWarnAction are false', () => {
      factory({ isWarnMode: false, hasLegacyWarnAction: false });

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      factory();
    });

    it('emits change event when radio group selection changes to warn', async () => {
      await findRadioGroup().vm.$emit('change', 'warn');

      expect(wrapper.emitted('change')).toEqual([['warn']]);
    });

    it('emits change event when radio group selection changes to enforce', async () => {
      await findRadioGroup().vm.$emit('change', 'enforce');

      expect(wrapper.emitted('change')).toEqual([['enforce']]);
    });

    it('emits multiple change events correctly', async () => {
      await findRadioGroup().vm.$emit('change', 'warn');
      await findRadioGroup().vm.$emit('change', 'enforce');

      expect(wrapper.emitted('change')).toEqual([['warn'], ['enforce']]);
    });
  });
});
