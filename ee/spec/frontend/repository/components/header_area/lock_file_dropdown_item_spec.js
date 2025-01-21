import { GlDisclosureDropdownItem, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';
import projectInfoQuery from 'ee_component/repository/queries/project_info.query.graphql';
import { projectMock, userPermissionsMock } from 'ee_jest/repository/mock_data';
import LockFileDropdownItem from 'ee_component/repository/components/header_area/lock_file_dropdown_item.vue';
import { createAlert } from '~/alert';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('LockFileDropdownItem component', () => {
  let wrapper;
  let fakeApollo;

  const projectInfoQueryMockResolver = jest
    .fn()
    .mockResolvedValue({ data: { project: projectMock } });
  const projectInfoQueryErrorResolver = jest.fn().mockRejectedValue(new Error('Request failed'));

  const lochPathMutationResolver = jest.fn();

  const createComponent = ({
    mutationResolver = lochPathMutationResolver,
    projectInfoResolver = projectInfoQueryMockResolver,
  } = {}) => {
    window.gon = { current_username: projectMock.pathLocks.nodes[0].user.username };
    fakeApollo = createMockApollo([
      [projectInfoQuery, projectInfoResolver],
      [lockPathMutation, mutationResolver],
    ]);

    wrapper = shallowMount(LockFileDropdownItem, {
      apolloProvider: fakeApollo,
      propsData: {
        name: 'locked_file.js',
        path: 'some/path/locked_file.js',
        projectPath: 'some/project/path',
      },
    });
  };

  let lockMutationMock;
  const findLockFileDropdownItem = () => wrapper.findComponent(GlDisclosureDropdownItem);
  const findModal = () => wrapper.findComponent(GlModal);
  const clickSubmit = () => findModal().vm.$emit('primary');
  const clickHide = () => findModal().vm.$emit('hide');

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  afterEach(() => {
    fakeApollo = null;
  });

  it('renders disabled the lock dropdown item if user can not lock a file', async () => {
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

    expect(findLockFileDropdownItem().props('item')).toMatchObject({
      extraAttrs: { disabled: true },
    });
  });

  it('renders disabled until query fetches projects info', async () => {
    const projectInfoQueryLoading = jest.fn().mockResolvedValue(new Promise(() => {}));
    createComponent({
      projectInfoResolver: projectInfoQueryLoading,
    });
    await waitForPromises();
    expect(projectInfoQueryLoading).toHaveBeenCalled();
    expect(findLockFileDropdownItem().props('item')).toMatchObject({
      extraAttrs: { disabled: true },
    });
  });

  it('renders disabled while mutation is executed', async () => {
    const lockMutationExecuting = jest.fn().mockResolvedValue(new Promise(() => {}));
    createComponent({
      mutationResolver: lockMutationExecuting,
    });
    await waitForPromises();
    findLockFileDropdownItem().vm.$emit('action');
    clickSubmit();
    await waitForPromises();

    expect(lockMutationExecuting).toHaveBeenCalled();
    expect(findLockFileDropdownItem().props('item')).toMatchObject({
      extraAttrs: { disabled: true },
    });
  });

  it('renders the Lock dropdown item label, when file is not locked', async () => {
    const projectWithNoLocks = {
      data: {
        project: {
          ...projectMock,
          pathLocks: { __typename: 'PathLockConnection', nodes: [] },
        },
      },
    };

    createComponent({
      projectInfoResolver: jest.fn().mockResolvedValue(projectWithNoLocks),
    });
    await waitForPromises();

    expect(findLockFileDropdownItem().props('item')).toMatchObject({
      text: 'Lock',
      extraAttrs: { disabled: false },
    });
  });

  it('renders the Unlock dropdown item label, when file is locked', () => {
    expect(findLockFileDropdownItem().props('item')).toMatchObject({
      text: 'Unlock',
      extraAttrs: { disabled: false },
    });
  });

  it('creates an alert with the correct message, when projectInfo query fails', async () => {
    createComponent({ projectInfoResolver: projectInfoQueryErrorResolver });
    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({
      message: 'An error occurred while fetching lock information, please try again.',
    });
  });

  describe('Modal', () => {
    it('displays a confirm modal when the lock dropdown item is clicked', () => {
      findLockFileDropdownItem().vm.$emit('action');

      expect(findModal().text()).toBe('Are you sure you want to unlock locked_file.js?');
      expect(findModal().props('actionPrimary')).toMatchObject({
        text: 'Unlock',
      });
    });

    it('should hide the confirm modal when a hide action is triggered', async () => {
      await findLockFileDropdownItem().vm.$emit('action');
      expect(findModal().props('visible')).toBe(true);

      await clickHide();
      expect(findModal().props('visible')).toBe(false);
    });

    it('renders an alert when mutation results in an error', async () => {
      lockMutationMock = jest.fn().mockRejectedValue(new Error('Request failed'));
      createComponent({ mutationResolver: lockMutationMock });
      await waitForPromises();

      findLockFileDropdownItem().vm.$emit('action');
      clickSubmit();

      expect(lockMutationMock).toHaveBeenCalledWith({
        filePath: 'some/path/locked_file.js',
        lock: false,
        projectPath: 'some/project/path',
      });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while editing lock information, please try again.',
        captureError: true,
        error: expect.any(Error),
      });

      expect(findLockFileDropdownItem().props('item')).toMatchObject({
        text: 'Unlock',
        extraAttrs: { disabled: false },
      });
    });

    it('executes a lock mutation once lock is confirmed', () => {
      findLockFileDropdownItem().vm.$emit('action');
      clickSubmit();

      expect(lochPathMutationResolver).toHaveBeenCalledWith({
        filePath: 'some/path/locked_file.js',
        lock: false,
        projectPath: 'some/project/path',
      });
    });

    it('does not execute a lock mutation if lock not confirmed', () => {
      findLockFileDropdownItem().vm.$emit('action');

      expect(lochPathMutationResolver).not.toHaveBeenCalled();
    });
  });
});
