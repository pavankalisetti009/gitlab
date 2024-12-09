import { shallowMount } from '@vue/test-utils';
import { GlModal, GlCollapsibleListbox, GlFormInput } from '@gitlab/ui';
import DastVariablesModal from 'ee/security_configuration/dast_profiles/components/dast_variables_modal.vue';

describe('DastVariablesModal', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(DastVariablesModal, {
      propsData: props,
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findVariableSelector = () => wrapper.findComponent(GlCollapsibleListbox);
  const findValueInput = () => wrapper.findComponent(GlFormInput);

  beforeEach(() => {
    createComponent();
  });

  it('renders the modal', () => {
    expect(findModal().exists()).toBe(true);
  });

  it('renders all necessary components', () => {
    expect(findVariableSelector().exists()).toBe(true);
    expect(findValueInput().exists()).toBe(true);
  });

  it('emits addVariable event when modal is submitted', async () => {
    await findModal().vm.$emit('primary');
    expect(wrapper.emitted('addVariable')).toHaveLength(1);
  });
});
