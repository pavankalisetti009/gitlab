import { nextTick } from 'vue';
import { GlFormCheckbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RuleDrawer from '~/projects/settings/branch_rules/components/view/rule_drawer.vue';
import ItemsSelector from 'ee_component/projects/settings/branch_rules/components/view/items_selector.vue';
import {
  allowedToMergeDrawerProps,
  allowedToPushDrawerProps,
} from 'ee_else_ce_jest/projects/settings/branch_rules/components/view/mock_data';

describe('Edit Rule Drawer', () => {
  let wrapper;

  const findCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findAdministratorsCheckbox = () => findCheckboxes().at(0);
  const findMaintainersCheckbox = () => findCheckboxes().at(1);
  const findDevelopersAndMaintainersCheckbox = () => findCheckboxes().at(2);
  const findNoOneCheckbox = () => findCheckboxes().at(3);
  const findUsersSelector = () => wrapper.findByTestId('users-selector');
  const findGroupsSelector = () => wrapper.findByTestId('groups-selector');
  const findDeployKeysSelector = () => wrapper.findByTestId('deploy-keys-selector');
  const findSaveButton = () => wrapper.findByText('Save changes');

  const createComponent = (
    props = allowedToMergeDrawerProps,
    showEnterpriseAccessLevels = true,
  ) => {
    wrapper = shallowMountExtended(RuleDrawer, {
      components: { ItemsSelector },
      propsData: {
        ...props,
      },
      provide: {
        showEnterpriseAccessLevels,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('isOpen watcher', () => {
    beforeEach(() => createComponent({ ...allowedToMergeDrawerProps, roles: [30, 40, 60] }));

    it('renders drawer all checkboxes unchecked by default', () => {
      findCheckboxes().wrappers.forEach((checkbox) =>
        expect(checkbox.attributes('checked')).toBeUndefined(),
      );
    });

    it('updates the checkboxes to the correct state when isOpen is changed', async () => {
      wrapper.setProps({ isOpen: true }); // simulates the drawer being opened from the parent
      await nextTick();

      expect(findAdministratorsCheckbox().attributes('checked')).toBe('true');
      expect(findMaintainersCheckbox().attributes('checked')).toBe('true');
      expect(findDevelopersAndMaintainersCheckbox().attributes('checked')).toBe('true');
      expect(findNoOneCheckbox().attributes('checked')).toBeUndefined();
    });
  });

  it('renders Item Selector with users', () => {
    expect(findUsersSelector().props('items')).toMatchObject([
      {
        __typename: 'UserCore',
        avatarUrl: 'test.com/user.png',
        id: 123,
        name: 'peter',
        src: 'test.com/user.png',
        webUrl: 'test.com',
      },
    ]);
  });

  it('renders Item Selector with groups scoped to the project and without namespace dropdown', () => {
    expect(findGroupsSelector().props('items')).toMatchObject([]);
  });

  it('renders Item Selector with deploy keys', () => {
    createComponent(allowedToPushDrawerProps);

    expect(findDeployKeysSelector().props('items')).toMatchObject([
      {
        id: 123123,
        title: 'Deploy key 1',
        user: {
          name: 'User 1',
        },
      },
    ]);
  });

  it('enables the save button when users or groups are selected', async () => {
    findUsersSelector().vm.$emit('change', ['some data']);
    await nextTick();
    expect(findSaveButton().attributes('disabled')).toBeUndefined();
  });

  describe('when enterprise access levels are not enabled', () => {
    beforeEach(() => createComponent(allowedToMergeDrawerProps, false));

    it('does not render Item Selector with users', () => {
      expect(findUsersSelector().exists()).toBe(false);
    });

    it('does not render Item Selector with groups', () => {
      expect(findGroupsSelector().exists()).toBe(false);
    });
  });
});
