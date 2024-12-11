import { shallowMount } from '@vue/test-utils';
import { GlButton, GlSprintf, GlModal } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import projectInfoQuery from 'ee_component/repository/queries/project_info.query.graphql';
import currentUserQuery from '~/graphql_shared/queries/current_user.query.graphql';
import LockDirectoryButton from 'ee_component/repository/components/lock_directory_button.vue';
import { projectMock, userPermissionsMock, userMock } from 'ee_jest/repository/mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('LockDirectoryButton', () => {
  let wrapper;
  let fakeApollo;

  const currentUserMockResolver = jest.fn().mockResolvedValue(userMock);
  const signedOutUserResolver = jest.fn().mockResolvedValue({ data: { currentUser: null } });
  const currentUserErrorResolver = jest.fn().mockRejectedValue(new Error('Request failed'));

  const projectInfoQueryMockResolver = jest.fn().mockResolvedValue(projectMock);
  const projectInfoQueryErrorResolver = jest.fn().mockRejectedValue(new Error('Request failed'));

  const createComponent = ({
    fileLocks = true,
    props = {},
    projectInfoResolver = projectInfoQueryMockResolver,
    currentUserResolver = currentUserMockResolver,
  } = {}) => {
    fakeApollo = createMockApollo([
      [projectInfoQuery, projectInfoResolver],
      [currentUserQuery, currentUserResolver],
    ]);

    wrapper = shallowMount(LockDirectoryButton, {
      apolloProvider: fakeApollo,
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

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  afterEach(() => {
    fakeApollo = null;
  });

  describe('lock button', () => {
    it('does not render when fileLocks feature is not available', async () => {
      createComponent({ fileLocks: false });
      await waitForPromises();

      expect(currentUserMockResolver).toHaveBeenCalled();
      expect(findLockDirectoryButton().exists()).toBe(false);
    });

    it('does not render when user is not logged in', async () => {
      createComponent({
        currentUserResolver: signedOutUserResolver,
      });
      await waitForPromises();

      expect(findLockDirectoryButton().exists()).toBe(false);
    });

    it('renders when feature is available and user logged in', () => {
      expect(findLockDirectoryButton().exists()).toBe(true);
    });

    it('renders with loading state until query fetches projects info', async () => {
      createComponent({
        projectInfoResolver: projectInfoQueryMockResolver.mockReturnValue(new Promise(() => {})),
      });
      await waitForPromises();
      expect(projectInfoQueryMockResolver).toHaveBeenCalled();
      expect(findLockDirectoryButton().props('loading')).toBe(true);
    });

    it('renders disabled with correct tooltip if user does not have permissions to push code', async () => {
      const projectWithNoPushPermission = {
        ...projectMock,
        data: {
          project: {
            ...projectMock.data.project,
            userPermissions: {
              ...userPermissionsMock,
              pushCode: false,
            },
          },
        },
      };
      createComponent({
        projectInfoResolver: jest.fn().mockResolvedValue(projectWithNoPushPermission),
      });
      await waitForPromises();

      expect(findLockDirectoryButton().text()).toBe('Lock');
      expect(findLockDirectoryButton().props('disabled')).toBe(true);
      expect(wrapper.attributes('title')).toBe('You do not have permission to lock this');
    });
  });

  describe('modal', () => {
    it('shows a modal when clicked', async () => {
      findLockDirectoryButton().trigger('click');
      await waitForPromises();
      expect(findModal().exists()).toBe(true);
    });

    it('has a unique modal id', async () => {
      findLockDirectoryButton().trigger('click');
      await waitForPromises();
      expect(findModal().props('modalId')).toBe('lock-directory-modal-app-models');
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

  describe('alert', () => {
    it('creates an alert with the correct message, when projectInfo query fails', async () => {
      createComponent({
        projectInfoResolver: projectInfoQueryErrorResolver,
      });
      await waitForPromises();
      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while fetching lock information, please try again.',
      });
    });

    it('creates an alert with the correct message, when currentUser query fails', async () => {
      createComponent({
        currentUserResolver: currentUserErrorResolver,
      });
      await waitForPromises();
      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while fetching lock information, please try again.',
      });
    });
  });
});
