import {
  GlFormGroup,
  GlButton,
  GlSprintf,
  GlLink,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DastVariablesFormGroup from 'ee/security_configuration/dast_profiles/components/dast_variables_form_group.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import DastVariablesModal from 'ee/security_configuration/dast_profiles/components/dast_variables_modal.vue';
import { stubComponent } from 'helpers/stub_component';

describe('DastVariablesFormGroup', () => {
  let wrapper;

  const modalStub = { show: jest.fn(), hide: jest.fn() };
  const DastVariablesModalStub = stubComponent(DastVariablesModal, { methods: modalStub });

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DastVariablesFormGroup, {
      propsData: {
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlSprintf,
        DastVariablesModal: DastVariablesModalStub,
        GlDisclosureDropdownItem,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findAddVariableButton = () => wrapper.findComponent(GlButton);
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findHelpText = () => wrapper.findComponent(GlSprintf);
  const findModal = () => wrapper.findComponent(DastVariablesModal);
  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);

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

  it('renders the action buttons', () => {
    expect(findDropdown().exists()).toBe(true);

    const dropdownItems = findDropdown().findAllComponents(GlDisclosureDropdownItem);
    expect(dropdownItems).toHaveLength(2);
    expect(dropdownItems.at(0).text()).toBe('Edit');
    expect(dropdownItems.at(1).text()).toBe('Delete');
  });

  describe('add variable modal', () => {
    it('renders the component', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('shows modal when add variable button is clicked', () => {
      findAddVariableButton().vm.$emit('click');
      expect(modalStub.show).toHaveBeenCalled();
    });
  });
});
