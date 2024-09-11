import { GlCollapsibleListbox, GlFormInput, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  EXCEPT_BRANCHES,
  WITHOUT_EXCEPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import BlockGroupBranchModification from 'ee/security_orchestration/components/policy_editor/scan_result/settings/block_group_branch_modification.vue';

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
  const findExceptionDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findInput = () => wrapper.findComponent(GlFormInput);

  describe('rendering', () => {
    it('renders the default', () => {
      createComponent();
      expect(findLink().attributes('href')).toBe(
        '/help/user/project/repository/branches/protected#for-all-projects-in-a-group',
      );
      expect(findExceptionDropdown().exists()).toBe(true);
      expect(findExceptionDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      expect(findInput().exists()).toBe(false);
    });

    it('renders when enabled', () => {
      createComponent({ enabled: true });
      expect(findLink().attributes('href')).toBe(
        '/help/user/project/repository/branches/protected#for-all-projects-in-a-group',
      );
      expect(findExceptionDropdown().exists()).toBe(true);
      expect(findExceptionDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      expect(findInput().exists()).toBe(false);
    });

    it('renders when not enabled and without exceptions', () => {
      createComponent({ enabled: false });
      expect(findExceptionDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      expect(findInput().exists()).toBe(false);
    });

    it('renders when enabled and with exceptions', () => {
      createComponent({ enabled: true, exceptions: ['releases/*', 'main'] });
      expect(findExceptionDropdown().props('selected')).toBe(EXCEPT_BRANCHES);
      expect(findInput().exists()).toBe(true);
      expect(findInput().attributes('value')).toBe('releases/*,main');
    });
  });

  describe('events', () => {
    it('updates the policy when exceptions are added', async () => {
      createComponent({ enabled: true, exceptions: ['releases/*', 'main'] });
      await findExceptionDropdown().vm.$emit('select', WITHOUT_EXCEPTIONS);
      expect(wrapper.emitted('change')[0][0]).toEqual(true);
    });

    it('updates thie policy when exceptions are changed', async () => {
      createComponent({ enabled: true, exceptions: ['releases/*', 'main'] });
      await findInput().vm.$emit('input', 'releases/*');
      expect(wrapper.emitted('change')[0][0]).toEqual({
        enabled: true,
        exceptions: ['releases/*'],
      });
    });

    it('does not update the policy when exceptions are changed and the setting is not enabled', async () => {
      createComponent({ enabled: false });
      await findExceptionDropdown().vm.$emit('select', EXCEPT_BRANCHES);
      expect(wrapper.emitted('change')).toEqual(undefined);
    });
  });

  describe('when enabled', () => {
    it('resets to default state when disabled', async () => {
      createComponent({ enabled: true, exceptions: ['releases/*', 'main'] });
      expect(findExceptionDropdown().props('selected')).toBe(EXCEPT_BRANCHES);
      expect(findInput().attributes('value')).toBe('releases/*,main');

      await wrapper.setProps({ enabled: false });

      expect(findExceptionDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      expect(findInput().exists()).toBe(false);

      await findExceptionDropdown().vm.$emit('select', EXCEPT_BRANCHES);
      expect(findInput().attributes('value')).toBe('');
    });
  });
});
