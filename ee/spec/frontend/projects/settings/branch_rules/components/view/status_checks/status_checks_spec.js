import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import StatusChecks from 'ee/projects/settings/branch_rules/components/view/status_checks/status_checks.vue';
import createStatusCheckMutation from 'ee/projects/settings/branch_rules/mutations/external_status_check_create.mutation.graphql';
import updateStatusCheckMutation from 'ee/projects/settings/branch_rules/mutations/external_status_check_update.mutation.graphql';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  statusCheckCreateSuccessResponse,
  statusCheckUpdateSuccessResponse,
  statusCheckCreateNameTakenResponse,
  statusChecksRulesMock,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;
  let fakeApollo;

  const createComponent = (propsData = {}, createStatusCheckHandler, updateStatusCheckHandler) => {
    fakeApollo = createMockApollo([
      [createStatusCheckMutation, createStatusCheckHandler],
      [updateStatusCheckMutation, updateStatusCheckHandler],
    ]);

    wrapper = shallowMountExtended(StatusChecks, {
      apolloProvider: fakeApollo,
      propsData: {
        branchRuleId: 'gid://gitlab/Projects/BranchRule/1',
        projectPath: 'gid://gitlab/Project/1',
        ...propsData,
      },
      mocks: {
        $toast: {
          show: jest.fn(),
        },
      },
    });
  };

  beforeEach(() => {
    createAlert.mockClear();
  });
  afterEach(() => {
    fakeApollo = null;
  });

  const findStatusChecksTable = () => wrapper.findByTestId('status-checks-table');
  const findStatusChecksDrawer = () => wrapper.findByTestId('status-checks-drawer');

  it('should render loading state', async () => {
    createComponent();
    expect(findStatusChecksDrawer().props('isLoading')).toBe(false);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      statusChecksRulesMock[0],
      'create',
    );
    await nextTick();
    expect(findStatusChecksDrawer().props('isLoading')).toBe(true);
  });

  it('should create status check successfully', () => {
    const createStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckCreateSuccessResponse);
    createComponent({}, createStatusCheckHandlerSuccess);
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      statusChecksRulesMock[0],
      'create',
    );
    expect(createStatusCheckHandlerSuccess).toHaveBeenCalled();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });

  it('should close drawer and show a toast when no changes are made', () => {
    const updateStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckUpdateSuccessResponse);
    createComponent({}, () => {}, updateStatusCheckHandlerSuccess);
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksTable().vm.$emit('open-status-check-drawer', statusChecksRulesMock[0]);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      { ...statusChecksRulesMock[0] },
      'update',
    );
    expect(updateStatusCheckHandlerSuccess).not.toHaveBeenCalled();
    expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
      'No changes were made to the status check.',
    );
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });

  it('should update status check successfully', () => {
    const updateStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckUpdateSuccessResponse);
    createComponent({}, () => {}, updateStatusCheckHandlerSuccess);
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksTable().vm.$emit('open-status-check-drawer', statusChecksRulesMock[0]);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      { ...statusChecksRulesMock[0], name: 'new name' },
      'update',
    );
    expect(updateStatusCheckHandlerSuccess).toHaveBeenCalled();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });

  it('should pass the server validation errors down', async () => {
    const createStatusCheckHandlerValidationError = jest
      .fn()
      .mockResolvedValue(statusCheckCreateNameTakenResponse);
    createComponent({}, createStatusCheckHandlerValidationError);
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      statusChecksRulesMock[0],
      'create',
    );
    await waitForPromises();
    expect(createStatusCheckHandlerValidationError).toHaveBeenCalled();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });

  it('should close the drawer when close event is emitted', async () => {
    createComponent();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksTable().vm.$emit('open-status-check-drawer');
    await nextTick();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(true);
    findStatusChecksDrawer().vm.$emit('close-status-check-drawer');
    await nextTick();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });

  it('should show an error alert when request fails', async () => {
    const createStatusCheckHandlerError = jest
      .fn()
      .mockRejectedValue(new Error('Something went wrong'));
    createComponent({}, createStatusCheckHandlerError);
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      statusChecksRulesMock[0],
      'create',
    );
    expect(createStatusCheckHandlerError).toHaveBeenCalled();
    await waitForPromises();
    expect(createAlert).toHaveBeenCalledWith({
      message: 'Unable to create status check. Please try again.',
    });
  });
});
