import { shallowMount } from '@vue/test-utils';
import { GlFormGroup, GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import DastVariablesFormGroup from 'ee/security_configuration/dast_profiles/components/dast_variables_form_group.vue';
import { helpPagePath } from '~/helpers/help_page_helper';

describe('DastVariablesFormGroup', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(DastVariablesFormGroup, {
      propsData: {
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlSprintf,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findAddVariableButton = () => wrapper.findComponent(GlButton);
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findHelpText = () => wrapper.findComponent(GlSprintf);

  beforeEach(() => {
    createComponent();
  });

  it('mounts correctly', () => {
    expect(wrapper.exists()).toBe(true);
    expect(findFormGroup().exists()).toBe(true);
  });

  it('renders the add variable button correctly', () => {
    expect(findAddVariableButton().exists()).toBe(true);
    expect(findAddVariableButton().text()).toBe('Add variable');
  });

  it('renders the help text and link correctly', () => {
    expect(findHelpText().exists()).toBe(true);
    expect(findHelpLink().exists()).toBe(true);
    expect(findHelpLink().attributes('href')).toBe(
      helpPagePath('user/application_security/dast/browser/configuration/variables'),
    );
  });
});
