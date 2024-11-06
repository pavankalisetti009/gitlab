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
import { TOP_LEVEL_GROUPS } from 'ee_jest/security_orchestration/mocks/mock_data';

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

    it('renders when enabled and with exceptions', () => {
      createComponent({ enabled: true, exceptions: ['group-1', 'group-2'] });
      expect(findHasExceptionsDropdown().props('selected')).toBe(EXCEPT_GROUPS);
      expect(findExceptionsDropdown().exists()).toBe(true);
      expect(findExceptionsDropdown().props('selected')).toEqual(['group-1', 'group-2']);
    });
  });

  describe('events', () => {
    it('updates the policy when exceptions are added', async () => {
      createComponent({ enabled: true, exceptions: ['group-1', 'group-2'] });
      await findHasExceptionsDropdown().vm.$emit('select', WITHOUT_EXCEPTIONS);
      expect(wrapper.emitted('change')[0][0]).toEqual(true);
    });

    it('updates the policy when exceptions are changed', async () => {
      createComponent({ enabled: true, exceptions: ['group-1', 'group-2'] });
      await findExceptionsDropdown().vm.$emit('select', ['group-2']);
      expect(wrapper.emitted('change')[0][0]).toEqual({
        enabled: true,
        exceptions: ['group-2'],
      });
    });

    it('does not update the policy when exceptions are changed and the setting is not enabled', async () => {
      createComponent({ enabled: false });
      await findHasExceptionsDropdown().vm.$emit('select', EXCEPT_GROUPS);
      expect(wrapper.emitted('change')).toEqual(undefined);
    });
  });

  describe('error', () => {
    it('handles error', async () => {
      jest.spyOn(Api, 'groups').mockRejectedValue();
      createComponent({ enabled: true, exceptions: ['group-1', 'group-2'] });
      await waitForPromises();
      expect(findExceptionsDropdown().props('items')).toEqual([]);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong, unable to fetch groups',
      });
    });
  });
});
