import { GlModal, GlTruncateText } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { deleteMavenUpstream } from 'ee/api/virtual_registries_api';
import DeleteUpstreamWithModal from 'ee/packages_and_registries/virtual_registries/components/delete_upstream_with_modal.vue';

jest.mock('ee/api/virtual_registries_api', () => ({
  deleteMavenUpstream: jest.fn(),
}));

describe('DeleteUpstreamWithModal', () => {
  let wrapper;

  const defaultProps = {
    upstreamId: 123,
    upstreamName: 'Test upstream',
    registries: [],
  };

  const mockRegistries = [
    { id: 1, name: 'Registry 1' },
    { id: 2, name: 'Registry 2' },
    { id: 3, name: 'Registry 3' },
  ];

  const findModal = () => wrapper.findComponent(GlModal);
  const findTruncateText = () => wrapper.findComponent(GlTruncateText);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DeleteUpstreamWithModal, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      scopedSlots: {
        default: '<button @click="props.showModal">Delete</button>',
      },
    });
  };

  beforeEach(() => {
    deleteMavenUpstream.mockReset();
  });

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal with correct props', () => {
      const modal = findModal();

      expect(modal.props()).toMatchObject({
        modalId: 'delete-upstream-modal',
        size: 'md',
        actionPrimary: {
          text: 'Delete upstream',
          attributes: {
            variant: 'danger',
            category: 'primary',
          },
        },
        actionCancel: {
          text: 'Cancel',
        },
      });
      expect(modal.attributes('title')).toBe('Delete upstream?');
    });

    it('initially has modal closed', () => {
      expect(findModal().props('visible')).toBe(false);
    });

    it('slot props `showModal` opens the modal', async () => {
      await wrapper.find('button').trigger('click');

      expect(findModal().props('visible')).toBe(true);
    });

    it('closes modal when canceled event is triggered', async () => {
      await wrapper.find('button').trigger('click');
      expect(findModal().props('visible')).toBe(true);
      await findModal().vm.$emit('canceled');

      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('modal content', () => {
    describe('when upstream has no associated registries', () => {
      beforeEach(() => {
        createComponent();
      });

      it('shows simple confirmation message', () => {
        expect(wrapper.text()).toContain('Are you sure you want to delete Test upstream?');
      });

      it('does not show registries list', () => {
        expect(findTruncateText().exists()).toBe(false);
      });

      it('does not show warning message', () => {
        expect(wrapper.text()).not.toContain('This action cannot be undone');
      });
    });

    describe('when upstream has associated registries', () => {
      beforeEach(() => {
        createComponent({ registries: mockRegistries });
      });

      it('shows warning message with registry count', () => {
        expect(wrapper.text()).toContain(
          'You are about to delete this upstream used by 3 registries:',
        );
      });

      it('shows truncated list of registries', () => {
        const truncateText = findTruncateText();
        expect(truncateText.exists()).toBe(true);

        const registryItems = wrapper.findAll('li');
        expect(registryItems).toHaveLength(3);
        expect(registryItems.at(0).text()).toBe('Registry 1');
        expect(registryItems.at(1).text()).toBe('Registry 2');
        expect(registryItems.at(2).text()).toBe('Registry 3');
      });

      it('shows impact warning message', () => {
        expect(wrapper.text()).toContain(
          'This action cannot be undone. Deleting this upstream might impact registries associated with it.',
        );
      });

      it('does not show simple confirmation message', () => {
        expect(wrapper.text()).not.toContain('Are you sure you want to delete Test upstream?');
      });
    });
  });

  describe('delete functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls deleteMavenUpstream with correct parameters', async () => {
      deleteMavenUpstream.mockResolvedValue();

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(deleteMavenUpstream).toHaveBeenCalledWith({
        id: 123,
      });
    });

    it('emits success event when deletion succeeds', async () => {
      deleteMavenUpstream.mockResolvedValue();

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.emitted('success')).toHaveLength(1);
      expect(wrapper.emitted('error')).toBeUndefined();
    });

    it('emits error event when deletion fails', async () => {
      const error = new Error('API Error');
      deleteMavenUpstream.mockRejectedValue(error);

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
      expect(wrapper.emitted('error')[0]).toEqual([error]);
      expect(wrapper.emitted('success')).toBeUndefined();
    });
  });
});
