import { shallowMount } from '@vue/test-utils';
import { GlButton, GlModal } from '@gitlab/ui';
import PolicyExceptionsModal from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_modal.vue';
import RolesSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/roles_selector.vue';
import GroupsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/groups_selector.vue';
import TokensSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/tokens_selector.vue';
import BranchPatternSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/branch_pattern_selector.vue';
import { EXCEPTION_OPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';

describe('PolicyExceptionsModal', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMount(PolicyExceptionsModal, {
      propsData,
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findTabButtons = () => wrapper.findAllComponents(GlButton);
  const findRolesSelector = () => wrapper.findComponent(RolesSelector);
  const findGroupsSelector = () => wrapper.findComponent(GroupsSelector);
  const findTokensSelector = () => wrapper.findComponent(TokensSelector);
  const findBranchPatternSelector = () => wrapper.findComponent(BranchPatternSelector);

  beforeEach(() => {
    createComponent();
  });

  describe('initial state', () => {
    it('renders the modal with correct props', () => {
      const modal = findModal();

      expect(modal.exists()).toBe(true);
      expect(modal.props('title')).toBe(PolicyExceptionsModal.i18n.modalTitle);
      expect(modal.props('actionCancel').text).toBe('Cancel');
      expect(modal.props('actionPrimary').text).toBe('Add exception(s)');
      expect(modal.props('size')).toBe('md');
      expect(modal.props('modalId')).toBe('deny-allow-list-modal');
    });

    it('renders all tab buttons', () => {
      const buttons = findTabButtons();

      expect(buttons).toHaveLength(EXCEPTION_OPTIONS.length);

      EXCEPTION_OPTIONS.forEach((option, index) => {
        expect(buttons.at(index).text()).toBe(option.value);
      });
    });

    it('selects ROLES tab by default', () => {
      expect(findRolesSelector().exists()).toBe(true);
      expect(findGroupsSelector().exists()).toBe(false);
      expect(findTokensSelector().exists()).toBe(false);
      expect(findBranchPatternSelector().exists()).toBe(false);
    });
  });

  describe('tab selection', () => {
    it.each`
      index | componentName
      ${0}  | ${'RolesSelector'}
      ${1}  | ${'GroupsSelector'}
      ${2}  | ${'TokensSelector'}
      ${3}  | ${'BranchPatternSelector'}
    `('shows the correct component when %s tab is selected', async ({ index, componentName }) => {
      await findTabButtons().at(index).vm.$emit('click');

      expect(findTabButtons().at(index).classes()).not.toContain('!gl-text-current');
      expect(findRolesSelector().exists()).toBe(componentName === 'RolesSelector');
      expect(findGroupsSelector().exists()).toBe(componentName === 'GroupsSelector');
      expect(findTokensSelector().exists()).toBe(componentName === 'TokensSelector');
      expect(findBranchPatternSelector().exists()).toBe(componentName === 'BranchPatternSelector');
    });
  });
});
