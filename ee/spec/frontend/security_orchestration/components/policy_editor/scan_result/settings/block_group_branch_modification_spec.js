import { GlLink, GlSprintf } from '@gitlab/ui';
import Api from '~/api';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  EXCEPT_GROUPS,
  WITHOUT_EXCEPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import BlockGroupBranchModification from 'ee/security_orchestration/components/policy_editor/scan_result/settings/block_group_branch_modification.vue';
import { createMockGroup, TOP_LEVEL_GROUPS } from 'ee_jest/security_orchestration/mocks/mock_data';

jest.mock('~/alert');

describe('BlockGroupBranchModification', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(BlockGroupBranchModification, {
      propsData: {
        title: 'Best popover',
        enabled: true,
        ...propsData,
      },
      stubs: { GlSprintf },
    });
  };

  const findLink = () => wrapper.findComponent(GlLink);
  const findHasExceptionsDropdown = () => wrapper.findByTestId('has-exceptions-selector');
  const findExceptionsDropdown = () => wrapper.findByTestId('exceptions-selector');

  beforeEach(() => {
    jest.spyOn(Api, 'group').mockReturnValue(Promise.resolve(TOP_LEVEL_GROUPS[0]));
    jest.spyOn(Api, 'groups').mockReturnValue(Promise.resolve(TOP_LEVEL_GROUPS));
  });

  describe('rendering', () => {
    it('renders the default', () => {
      createComponent();
      expect(findLink().attributes('href')).toBe(
        '/help/user/project/repository/branches/protected#for-all-projects-in-a-group',
      );
      expect(findHasExceptionsDropdown().exists()).toBe(true);
      expect(findHasExceptionsDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      expect(findExceptionsDropdown().exists()).toBe(false);
    });

    it('renders when enabled', () => {
      createComponent({ enabled: true });
      expect(findLink().attributes('href')).toBe(
        '/help/user/project/repository/branches/protected#for-all-projects-in-a-group',
      );
      expect(findHasExceptionsDropdown().exists()).toBe(true);
      expect(findHasExceptionsDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      expect(findExceptionsDropdown().exists()).toBe(false);
    });

    it('renders when not enabled and without exceptions', () => {
      createComponent({ enabled: false });
      expect(findHasExceptionsDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      expect(findHasExceptionsDropdown().props('disabled')).toBe(true);
      expect(findExceptionsDropdown().exists()).toBe(false);
    });
  });

  describe('existing exceptions', () => {
    const EXCEPTIONS = [{ id: 1 }, { id: 2 }];

    beforeEach(async () => {
      jest
        .spyOn(Api, 'group')
        .mockReturnValueOnce(Promise.resolve(createMockGroup(EXCEPTIONS[0].id)))
        .mockReturnValueOnce(Promise.resolve(createMockGroup(EXCEPTIONS[1].id)));
      createComponent({ enabled: true, exceptions: EXCEPTIONS });
      await waitForPromises();
    });

    it('retrieves top-level groups', () => {
      expect(Api.groups).toHaveBeenCalledWith('', { top_level_only: true });
    });

    it('renders the except selection dropdown', () => {
      expect(findHasExceptionsDropdown().props('selected')).toBe(EXCEPT_GROUPS);
    });

    it('renders the group selection dropdown', () => {
      expect(findExceptionsDropdown().exists()).toBe(true);
      expect(findExceptionsDropdown().props('selected')).toEqual([1, 2]);
    });

    it('retrieves exception groups and uses them for the dropdown text', () => {
      expect(findExceptionsDropdown().props('toggleText')).toEqual('Group-1, Group-2');
    });

    it('updates the toggle text on selection', async () => {
      await wrapper.setProps({ enabled: true, exceptions: [...EXCEPTIONS, { id: 3 }] });
      await waitForPromises();
      expect(findExceptionsDropdown().props('toggleText')).toEqual('Group-1, Group-2 +1 more');
    });

    it('updates the toggle text on deselection', async () => {
      await wrapper.setProps({ enabled: true, exceptions: [{ id: 2 }] });
      await waitForPromises();
      expect(findExceptionsDropdown().props('toggleText')).toEqual('Group-2');
    });
  });

  describe('events', () => {
    it('updates the policy when exceptions are added', async () => {
      createComponent({ enabled: true, exceptions: [{ id: 1 }, { id: 2 }] });
      await findHasExceptionsDropdown().vm.$emit('select', WITHOUT_EXCEPTIONS);
      expect(wrapper.emitted('change')[0][0]).toEqual(true);
    });

    it('updates the policy when exceptions are changed', async () => {
      createComponent({ enabled: true, exceptions: [{ id: 1 }, { id: 2 }] });
      await findExceptionsDropdown().vm.$emit('select', [1]);
      expect(wrapper.emitted('change')[0][0]).toEqual({
        enabled: true,
        exceptions: [{ id: 1 }],
      });
    });

    it('does not update the policy when exceptions are changed and the setting is not enabled', async () => {
      createComponent({ enabled: false });
      await findHasExceptionsDropdown().vm.$emit('select', EXCEPT_GROUPS);
      expect(wrapper.emitted('change')).toEqual(undefined);
    });

    it('searches for groups', async () => {
      createComponent({ enabled: true, exceptions: [{ id: 1 }, { id: 2 }] });
      await findExceptionsDropdown().vm.$emit('search', 'git');
      expect(Api.groups).toHaveBeenCalledWith('git', { top_level_only: true });
    });
  });

  describe('error', () => {
    it('handles error', async () => {
      jest.spyOn(Api, 'groups').mockRejectedValue();
      createComponent({ enabled: true, exceptions: [{ id: 1 }, { id: 2 }] });
      await waitForPromises();
      expect(findExceptionsDropdown().props('items')).toEqual([]);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong, unable to fetch groups',
      });
    });
  });
});
