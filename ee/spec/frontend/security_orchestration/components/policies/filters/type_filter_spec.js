import { GlCollapsibleListbox, GlListboxItem } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import {
  POLICY_TYPE_FILTER_OPTIONS,
  VULNERABILITY_MANAGEMENT_FILTER_OPTION,
} from 'ee/security_orchestration/components/policies/constants';
import TypeFilter from 'ee/security_orchestration/components/policies/filters/type_filter.vue';

describe('TypeFilter component', () => {
  let wrapper;

  const createWrapper = ({
    value = '',
    glFeatures = {
      vulnerabilityManagementPolicyTypeGroup: true,
      vulnerabilityManagementPolicyType: true,
    },
  } = {}) => {
    wrapper = shallowMount(TypeFilter, {
      propsData: {
        value,
      },
      provide: {
        glFeatures,
      },
      stubs: {
        GlCollapsibleListbox,
      },
    });
  };

  const findToggle = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('standard policy type', () => {
    it('passes correct options to listbox', () => {
      createWrapper();

      expect(findToggle().props('items')).toMatchObject(
        Object.values({ ...POLICY_TYPE_FILTER_OPTIONS, ...VULNERABILITY_MANAGEMENT_FILTER_OPTION }),
      );
    });

    it('does not pass vulnerability management option when feature flag is disabled', () => {
      // Both project-level and group-level feature flags need to be disabled
      createWrapper({
        glFeatures: {
          vulnerabilityManagementPolicyType: false,
          vulnerabilityManagementPolicyTypeGroup: false,
        },
      });

      expect(findToggle().props('items')).toMatchObject(Object.values(POLICY_TYPE_FILTER_OPTIONS));
    });

    it.each`
      value                                              | expectedToggleText
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}            | ${POLICY_TYPE_FILTER_OPTIONS.ALL.text}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value} | ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text}
    `('selects the correct option when value is "$value"', ({ value, expectedToggleText }) => {
      createWrapper({ value });

      expect(findToggle().props('toggleText')).toBe(expectedToggleText);
    });

    it('displays the "All policies" option first', () => {
      createWrapper();

      expect(wrapper.findAllComponents(GlListboxItem).at(0).text()).toBe(
        POLICY_TYPE_FILTER_OPTIONS.ALL.text,
      );
    });

    it('emits an event when an option is selected', () => {
      createWrapper();

      expect(wrapper.emitted('input')).toBeUndefined();

      findToggle().vm.$emit('select', POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value);

      expect(wrapper.emitted('input')).toEqual([[POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]]);
    });
  });
});
