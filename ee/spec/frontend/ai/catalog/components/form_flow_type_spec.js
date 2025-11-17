import { shallowMount } from '@vue/test-utils';
import { GlFormRadioGroup } from '@gitlab/ui';
import FormFlowType from 'ee/ai/catalog/components/form_flow_type.vue';

describe('FormFlowType', () => {
  let wrapper;

  const defaultProps = {
    id: 'field-flow-type',
    value: 'FLOW',
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(FormFlowType, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);

  beforeEach(() => {
    createComponent();
  });

  it('renders radio group with correct props', () => {
    expect(findRadioGroup().attributes()).toMatchObject({
      id: defaultProps.id,
      checked: defaultProps.value,
    });
    expect(findRadioGroup().attributes('disabled')).toBeUndefined();
    expect(findRadioGroup().props('options')).toEqual([
      { value: 'FLOW', text: 'Flow' },
      { value: 'THIRD_PARTY_FLOW', text: 'External' },
    ]);
  });

  it('emits input event when a radio option is selected', () => {
    findRadioGroup().vm.$emit('input', 'THIRD_PARTY_FLOW');

    expect(wrapper.emitted('input')).toEqual([['THIRD_PARTY_FLOW']]);
  });

  describe('when disabled prop is true', () => {
    beforeEach(() => {
      createComponent({ props: { disabled: true } });
    });

    it('renders radio group as disabled', () => {
      expect(findRadioGroup().attributes('disabled')).toBeDefined();
    });
  });
});
