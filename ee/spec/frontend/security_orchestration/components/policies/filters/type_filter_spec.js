import { GlCollapsibleListbox, GlListboxItem } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { POLICY_TYPE_FILTER_OPTIONS } from 'ee/security_orchestration/components/policies/constants';
import TypeFilter from 'ee/security_orchestration/components/policies/filters/type_filter.vue';

describe('TypeFilter component', () => {
  let wrapper;

  const createWrapper = ({ propsData: { value = '' } = {} } = {}) => {
    wrapper = shallowMount(TypeFilter, {
      propsData: {
        value,
      },
      stubs: {
        GlCollapsibleListbox,
      },
    });
  };

  const findToggle = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('standard policy type', () => {
    it.each`
      value                                              | expectedToggleText
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}            | ${POLICY_TYPE_FILTER_OPTIONS.ALL.text}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value} | ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text}
    `('selects the correct option when value is "$value"', ({ value, expectedToggleText }) => {
      createWrapper({ propsData: { value } });

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

  describe('new pipeline execution policy type', () => {
    it('selects the correct option for new pipeline execution type', () => {
      createWrapper({
        propsData: {
          value: POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value,
        },
      });

      expect(findToggle().props('toggleText')).toBe(
        POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.text,
      );
    });

    it('emits an event when an option for pipeline execution type is selected', () => {
      createWrapper();

      expect(wrapper.emitted('input')).toBeUndefined();

      findToggle().vm.$emit('select', POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value);

      expect(wrapper.emitted('input')).toEqual([
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value],
      ]);
    });
  });
});
