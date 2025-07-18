import { shallowMount } from '@vue/test-utils';
import ApplySecurityAttributes from 'ee/security_configuration/security_attributes/components/apply_security_attributes.vue';

describe('ApplySecurityAttributes', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(ApplySecurityAttributes);
  };

  it('renders page heading, tab, and description', () => {
    createComponent();

    expect(wrapper.text()).toContain(
      'Security attributes help classify and organize your projects',
    );
  });
});
