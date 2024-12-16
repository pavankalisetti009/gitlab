import { shallowMount } from '@vue/test-utils';
import { GlButton, GlSprintf, GlModal, GlTooltip } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import projectInfoQuery from 'ee_component/repository/queries/project_info.query.graphql';
import currentUserQuery from '~/graphql_shared/queries/current_user.query.graphql';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import LockDirectoryButton from 'ee_component/repository/components/lock_directory_button.vue';
import {
  projectMock,
  exactDirectoryLock,
  upstreamDirectoryLock,
  downstreamDirectoryLock,
  userPermissionsMock,
  userMock,
  lockPathMutationMock,
} from 'ee_jest/repository/mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('LockDirectoryButton', () => {
  let wrapper;
  let fakeApollo;

  const currentUserMockResolver = jest.fn().mockResolvedValue(userMock);
  const signedOutUserResolver = jest.fn().mockResolvedValue({ data: { currentUser: null } });
  const currentUserErrorResolver = jest.fn().mockRejectedValue(new Error('Request failed'));

  const projectInfoQueryMockResolver = jest
    .fn()
    .mockResolvedValue({ data: { project: projectMock } });
  const projectInfoQueryErrorResolver = jest.fn().mockRejectedValue(new Error('Request failed'));

  const lockPathMutationMockResolver = jest.fn().mockResolvedValue(lockPathMutationMock);
  const lockPathMutationErrorResolver = jest.fn().mockRejectedValue(new Error('Request failed'));

  const createComponent = ({
    fileLocks = true,
    props = {},
    projectInfoResolver = projectInfoQueryMockResolver,
    currentUserResolver = currentUserMockResolver,
    lockPathMutationResolver = lockPathMutationMockResolver,
  } = {}) => {
    fakeApollo = createMockApollo([
      [projectInfoQuery, projectInfoResolver],
      [currentUserQuery, currentUserResolver],
      [lockPathMutation, lockPathMutationResolver],
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
        path: 'test/component',
        ...props,
      },
      stubs: {
        GlSprintf,
        GlButton,
        GlModal,
        GlTooltip,
      },
    });
  };

  const findLockDirectoryButton = () => wrapper.findComponent(GlButton);
  const findModal = () => wrapper.findComponent(GlModal);
  const findTooltip = () => wrapper.findComponent(GlTooltip);

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
        data: {
          project: {
            ...projectMock,
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
      expect(findTooltip().text()).toBe('You do not have permission to lock this');
    });

    it('renders enabled without a tooltip when user can push code', async () => {
      const projectWithNoLocks = {
        data: {
          project: {
            ...projectMock,
            pathLocks: { __typename: 'PathLockConnection', nodes: [] },
          },
        },
      };
      createComponent({ projectInfoResolver: jest.fn().mockResolvedValue(projectWithNoLocks) });
      await waitForPromises();

      expect(findLockDirectoryButton().text()).toBe('Lock');
      expect(findLockDirectoryButton().props('disabled')).toBe(false);
      expect(findTooltip().exists()).toBe(false);
    });
  });

  describe('lock types', () => {
    it.each`
      mock                       | type                  | isExactLock | isUpstreamLock | isDownstreamLock
      ${exactDirectoryLock}      | ${'isExactLock'}      | ${true}     | ${false}       | ${false}
      ${upstreamDirectoryLock}   | ${'isUpstreamLock'}   | ${false}    | ${true}        | ${false}
      ${downstreamDirectoryLock} | ${'isDownstreamLock'} | ${false}    | ${false}       | ${true}
    `(
      'correctly assigns the lock type as $type depending on PathLock data',
      async ({ mock, type, isExactLock, isUpstreamLock, isDownstreamLock }) => {
        createComponent({
          projectInfoResolver: jest.fn().mockResolvedValue({
            data: {
              project: {
                ...projectMock,
                pathLocks: {
                  __typename: 'PathLockConnection',
                  nodes: [mock],
                },
              },
            },
          }),
        });
        await waitForPromises();

        expect(wrapper.vm.$data.pathLock[type]).toBe(true);
        expect(wrapper.vm.$data.pathLock.isExactLock).toBe(isExactLock);
        expect(wrapper.vm.pathLock.isUpstreamLock).toBe(isUpstreamLock);
        expect(wrapper.vm.pathLock.isDownstreamLock).toBe(isDownstreamLock);
      },
    );
  });

  describe('when there is an exact lock', () => {
    it('renders an enabled "Unlock" button with a tooltip when user is allowed to unlock', async () => {
      createComponent({
        projectInfoResolver: jest.fn().mockResolvedValue({
          data: {
            project: {
              ...projectMock,
              pathLocks: {
                __typename: 'PathLockConnection',
                nodes: [exactDirectoryLock],
              },
            },
          },
        }),
      });
      await waitForPromises();
      expect(findLockDirectoryButton().text()).toBe('Unlock');
      expect(findLockDirectoryButton().props('disabled')).toBe(false);
      expect(findTooltip().text()).toContain('Locked by User2');
    });

    it('renders an enabled "Unlock" button when lock author is allowed to unlock', async () => {
      createComponent({
        projectInfoResolver: jest.fn().mockResolvedValue({
          data: {
            project: {
              ...projectMock,
              pathLocks: {
                __typename: 'PathLockConnection',
                nodes: [
                  {
                    ...exactDirectoryLock,
                    user: {
                      __typename: 'CurrentUser',
                      id: 'gid://gitlab/User/1',
                      username: 'root',
                      name: 'Administrator',
                    },
                  },
                ],
              },
            },
          },
        }),
      });
      await waitForPromises();

      expect(findLockDirectoryButton().text()).toBe('Unlock');
      expect(findLockDirectoryButton().props('disabled')).toBe(false);
      expect(findTooltip().exists()).toBe(false);
    });

    it('renders a disabled "Unlock" button with a tooltip when user is not allowed to unlock', async () => {
      createComponent({
        projectInfoResolver: jest.fn().mockResolvedValue({
          data: {
            project: {
              ...projectMock,
              userPermissions: {
                ...userPermissionsMock,
                adminPathLocks: false,
                canPushCode: false,
              },
              pathLocks: {
                __typename: 'PathLockConnection',
                nodes: [exactDirectoryLock],
              },
            },
          },
        }),
      });
      await waitForPromises();
      expect(findLockDirectoryButton().text()).toBe('Unlock');
      expect(findLockDirectoryButton().props('disabled')).toBe(true);
      expect(findTooltip().text()).toContain(
        'Locked by User2. You do not have permission to unlock this',
      );
    });
  });

  describe('when there is an upstream lock', () => {
    it('renders a disabled "Unlock" button with a tooltip when user is allowed to unlock', async () => {
      createComponent({
        projectInfoResolver: jest.fn().mockResolvedValue({
          data: {
            project: {
              ...projectMock,
              pathLocks: {
                __typename: 'PathLockConnection',
                nodes: [upstreamDirectoryLock],
              },
            },
          },
        }),
      });
      await waitForPromises();

      expect(findLockDirectoryButton().text()).toBe('Unlock');
      expect(findLockDirectoryButton().props('disabled')).toBe(true);
      expect(findTooltip().text()).toContain('Unlock that directory in order to unlock this');
    });

    it('renders a disabled "Unlock" button with a tooltip when user is not allowed to unlock', async () => {
      createComponent({
        projectInfoResolver: jest.fn().mockResolvedValue({
          data: {
            project: {
              ...projectMock,
              userPermissions: {
                ...userPermissionsMock,
                adminPathLocks: false,
              },
              pathLocks: {
                __typename: 'PathLockConnection',
                nodes: [upstreamDirectoryLock],
              },
            },
          },
        }),
      });
      await waitForPromises();

      expect(findLockDirectoryButton().text()).toBe('Unlock');
      expect(findLockDirectoryButton().props('disabled')).toBe(true);
      expect(findTooltip().text()).toContain('You do not have permission to unlock it');
    });
  });

  describe('when there is a downstream lock', () => {
    it('renders a disabled "Lock" button with a tooltip when user is allowed to lock', async () => {
      createComponent({
        projectInfoResolver: jest.fn().mockResolvedValue({
          data: {
            project: {
              ...projectMock,
              pathLocks: {
                __typename: 'PathLockConnection',
                nodes: [downstreamDirectoryLock],
              },
            },
          },
        }),
      });
      await waitForPromises();

      expect(findLockDirectoryButton().text()).toBe('Lock');
      expect(findLockDirectoryButton().props('disabled')).toBe(true);
      expect(findTooltip().text()).toContain(
        'This directory cannot be locked while User2 has a lock on "test/component/icon". Unlock this in order to proceed',
      );
    });

    it('renders a disabled "Lock" button with a tooltip when user is not allowed to lock', async () => {
      createComponent({
        projectInfoResolver: jest.fn().mockResolvedValue({
          data: {
            project: {
              ...projectMock,
              userPermissions: {
                ...userPermissionsMock,
                adminPathLocks: false,
              },
              pathLocks: {
                __typename: 'PathLockConnection',
                nodes: [downstreamDirectoryLock],
              },
            },
          },
        }),
      });
      await waitForPromises();

      expect(findLockDirectoryButton().text()).toBe('Lock');
      expect(findLockDirectoryButton().props('disabled')).toBe(true);
      expect(findTooltip().text()).toContain(
        'This directory cannot be locked while User2 has a lock on "test/component/icon". You do not have permission to unlock it',
      );
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
      expect(findModal().props('modalId')).toBe('lock-directory-modal-test-component');
    });

    it('displays correct content, when user tries to lock the directory', async () => {
      findLockDirectoryButton().trigger('click');
      await waitForPromises();
      expect(findModal().text()).toContain('Are you sure you want to lock this directory?');
    });

    it('displays correct content, when user tries to unlock the directory', async () => {
      createComponent({
        projectInfoResolver: jest.fn().mockResolvedValue({
          data: {
            project: {
              ...projectMock,
              pathLocks: {
                __typename: 'PathLockConnection',
                nodes: [exactDirectoryLock],
              },
            },
          },
        }),
      });
      await waitForPromises();
      findLockDirectoryButton().trigger('click');
      await waitForPromises();
      expect(findModal().text()).toContain('Are you sure you want to unlock this directory?');
    });
  });

  describe('when the user confirms the action in the modal', () => {
    useMockLocationHelper();

    it('calls the mutation and reloads the page, when mutation is successful', async () => {
      findLockDirectoryButton().trigger('click');
      await waitForPromises();
      findModal().vm.$emit('primary');
      await waitForPromises();
      expect(lockPathMutationMockResolver).toHaveBeenCalledWith({
        filePath: 'test/component',
        projectPath: 'group/project',
        lock: true,
      });
      expect(window.location.reload).toHaveBeenCalled();
    });

    it('calls the mutation and and creates an alert with the correct message, when mutation fails', async () => {
      createComponent({
        lockPathMutationResolver: lockPathMutationErrorResolver,
      });
      await waitForPromises();
      findLockDirectoryButton().trigger('click');
      await waitForPromises();
      findModal().vm.$emit('primary');
      await waitForPromises();
      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while editing lock information, please try again.',
        captureError: true,
        error: expect.any(Error),
      });
      expect(window.location.reload).not.toHaveBeenCalled();
    });
  });

  describe('when user cancels the action in the modal', () => {
    it('does not call the mutation', async () => {
      findLockDirectoryButton().trigger('click');
      await waitForPromises();
      findModal().vm.$emit('cancel');
      await waitForPromises();
      expect(lockPathMutationMockResolver).not.toHaveBeenCalled();
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
