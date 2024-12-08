import { shallowMount } from '@vue/test-utils';
import { GlButton, GlSprintf, GlModal } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import LockDirectoryButton from 'ee_component/repository/components/lock_directory_button.vue';

describe('LockDirectoryButton', () => {
  let wrapper;

  const createComponent = ({ fileLocks = true, props = {} } = {}) => {
    wrapper = shallowMount(LockDirectoryButton, {
      provide: {
        glFeatures: {
          fileLocks,
        },
      },
      propsData: {
        projectPath: 'group/project',
        path: 'app/models',
        ...props,
      },
      stubs: {
        GlSprintf,
        GlButton,
        GlModal,
      },
    });
  };

  const findLockDirectoryButton = () => wrapper.findComponent(GlButton);
  const findModal = () => wrapper.findComponent(GlModal);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('does not render when fileLocks feature is not available', async () => {
      createComponent({ fileLocks: false });
      await waitForPromises();
      expect(findLockDirectoryButton().exists()).toBe(false);
    });

    it('does not render when user is not logged in', async () => {
      // temporarily setting the user this way,
      // will change to mocked query in https://gitlab.com/gitlab-org/gitlab/-/merge_requests/173576
      wrapper.vm.user = { id: null };
      await waitForPromises();

      expect(findLockDirectoryButton().exists()).toBe(false);
    });

    it('renders lock button when feature is available and user logged in', async () => {
      await waitForPromises();
      expect(findLockDirectoryButton().exists()).toBe(true);
    });
  });

  describe('modal', () => {
    it('shows a modal when clicked', async () => {
      findLockDirectoryButton().trigger('click');
      await waitForPromises();
      expect(findModal().exists()).toBe(true);
    });

    it.each`
      locked   | expectedContent
      ${true}  | ${'Are you sure you want to unlock this directory?'}
      ${false} | ${'Are you sure you want to lock this directory?'}
    `('displays $expectedContent when isLocked is $locked', async ({ locked, expectedContent }) => {
      await waitForPromises();
      wrapper.vm.isLocked = locked;
      findLockDirectoryButton().trigger('click');
      await waitForPromises();
      expect(findModal().text()).toContain(expectedContent);
    });
  });
});
