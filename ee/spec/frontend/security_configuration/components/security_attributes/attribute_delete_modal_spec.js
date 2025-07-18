import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AttributeDeleteModal from 'ee/security_configuration/components/security_attributes/attribute_delete_modal.vue';

describe('AttributeDeleteModal', () => {
  let wrapper;

  const attribute = { name: 'USA::Austin' };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AttributeDeleteModal, {
      propsData: {
        visible: true,
        attribute,
        ...props,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  it('renders the modal with the correct props and message', () => {
    createComponent();

    expect(findModal().props()).toMatchObject({
      modalId: 'delete-security-attribute-modal',
      title: 'Delete security attribute?',
      visible: true,
    });

    expect(findModal().text()).toBe(
      `Deleting the "${attribute.name}" Security Attribute will permanently remove it from its category and any projects where it is applied. This action cannot be undone.`,
    );
  });
});
