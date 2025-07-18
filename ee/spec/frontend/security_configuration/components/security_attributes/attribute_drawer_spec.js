import { GlDrawer } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AttributeDrawer from 'ee/security_configuration/components/security_attributes/attribute_drawer.vue';
import SecurityAttributeForm from 'ee/security_configuration/components/security_attributes/attribute_form.vue';
import AttributeDeleteModal from 'ee/security_configuration/components/security_attributes/attribute_delete_modal.vue';
import { DRAWER_MODES } from 'ee/security_configuration/components/security_attributes/constants';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';

describe('AttributeDrawer', () => {
  let wrapper;

  const attribute = { name: 'Attribute 1', color: '#fff', description: 'A attribute' };

  const createComponent = () => {
    wrapper = shallowMountExtended(AttributeDrawer, {
      stubs: {
        GlDrawer,
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findForm = () => wrapper.findComponent(SecurityAttributeForm);
  const findDeleteModal = () => wrapper.findComponent(AttributeDeleteModal);
  const findSubmitButton = () => wrapper.findByTestId('submit-btn');
  const findCancelButton = () => wrapper.findByTestId('cancel-btn');
  const findDeleteButton = () => wrapper.findByTestId('delete-btn');

  beforeEach(() => {
    createComponent();
    wrapper.vm.open(DRAWER_MODES.ADD, attribute);
  });

  it('renders GlDrawer open with correct props', () => {
    expect(findDrawer().exists()).toBe(true);
    expect(findDrawer().props()).toMatchObject({
      open: true,
      zIndex: DRAWER_Z_INDEX,
    });
  });

  it('renders AttributeForm with correct props', () => {
    expect(findForm().props()).toMatchObject({
      attribute,
      mode: DRAWER_MODES.ADD,
    });
  });

  it('renders AttributeDeleteModal with correct visibility and attribute', () => {
    expect(findDeleteModal().props()).toMatchObject({
      visible: false,
      attribute,
    });
  });

  it('renders submit and cancel buttons', () => {
    expect(findSubmitButton().exists()).toBe(true);
    expect(findCancelButton().exists()).toBe(true);
  });

  it('does not render delete button in ADD mode', () => {
    expect(findDeleteButton().exists()).toBe(false);
  });
});
