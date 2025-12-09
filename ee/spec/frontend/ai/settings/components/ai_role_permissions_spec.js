import { GlFormGroup, GlFormSelect } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiRolePermissions from 'ee/ai/settings/components/ai_role_permissions.vue';
import {
  ACCESS_LEVEL_DEVELOPER_INTEGER,
  ACCESS_LEVEL_MAINTAINER_INTEGER,
  ACCESS_LEVEL_OWNER_INTEGER,
  ACCESS_LEVEL_ADMIN_INTEGER,
} from '~/access_level/constants';

describe('AiRolePermissions', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findMainFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findEnableRoleFormGroup = () => wrapper.find('[label-for="enable-role-selector"]');
  const findExecuteRoleFormGroup = () => wrapper.find('[label-for="execute-role-selector"]');
  const findManageRoleFormGroup = () => wrapper.find('[label-for="manage-role-selector"]');
  const findEnableRoleSelect = () => wrapper.findByTestId('enable-role-selector');
  const findExecuteRoleSelect = () => wrapper.findByTestId('execute-role-selector');
  const findManageRoleSelect = () => wrapper.findByTestId('manage-role-selector');

  const createWrapper = ({ props = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(AiRolePermissions, {
      propsData: {
        enableOnProjectsMinimumRole: ACCESS_LEVEL_OWNER_INTEGER,
        manageMinimumRole: ACCESS_LEVEL_MAINTAINER_INTEGER,
        executeMinimumRole: ACCESS_LEVEL_DEVELOPER_INTEGER,
        ...props,
      },
      provide: {
        duoAgentPlatformRolePermissionsEnabled: true,
        ...provide,
      },
      stubs: {
        GlFormSelect,
        ...stubs,
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the main form group with correct title', () => {
      expect(findMainFormGroup().attributes('label')).toBe('Agent & Flow Permissions');
    });

    it('renders the section description', () => {
      createWrapper({ stubs: { GlFormGroup } });

      expect(findMainFormGroup().text()).toContain(
        'Define the minimum role level to perform each of the following actions',
      );
    });

    it('renders enable role form group with correct label and description', () => {
      const enableFormGroup = findEnableRoleFormGroup();

      expect(enableFormGroup.attributes('label')).toBe('Enable');
      expect(enableFormGroup.attributes('description')).toBe(
        'Minimum role required to enable agents and flows on projects.',
      );
      expect(enableFormGroup.attributes('label-for')).toBe('enable-role-selector');
    });

    it('renders manage role form group with correct label and description', () => {
      const manageFormGroup = findManageRoleFormGroup();

      expect(manageFormGroup.attributes('label')).toBe('Manage');
      expect(manageFormGroup.attributes('description')).toBe(
        'Minimum role required to create, duplicate, edit, delete, and show agents and flows.',
      );
      expect(manageFormGroup.attributes('label-for')).toBe('manage-role-selector');
    });

    it('renders execute role form group with correct label and description', () => {
      const executeFormGroup = findExecuteRoleFormGroup();

      expect(executeFormGroup.attributes('label')).toBe('Execute');
      expect(executeFormGroup.attributes('description')).toBe(
        'Minimum role required to execute agents and flows.',
      );
      expect(executeFormGroup.attributes('label-for')).toBe('execute-role-selector');
    });
  });

  describe('enable role selector', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders enable role select with correct options', () => {
      const enableSelect = findEnableRoleSelect();

      expect(enableSelect.attributes('id')).toBe('enable-role-selector');
      expect(enableSelect.props('options')).toEqual([
        { text: 'Maintainer', value: ACCESS_LEVEL_MAINTAINER_INTEGER },
        { text: 'Owner', value: ACCESS_LEVEL_OWNER_INTEGER },
      ]);
    });

    describe('when isAdminInstanceDuoHome is true', () => {
      beforeEach(() => {
        createWrapper({ provide: { isAdminInstanceDuoHome: true } });
      });

      it('includes Admin role in manage role options', () => {
        expect(findEnableRoleSelect().props('options')).toEqual([
          { text: 'Maintainer', value: ACCESS_LEVEL_MAINTAINER_INTEGER },
          { text: 'Owner', value: ACCESS_LEVEL_OWNER_INTEGER },
          { text: 'Admin', value: ACCESS_LEVEL_ADMIN_INTEGER },
        ]);
      });
    });

    it('sets initial value from enableOnProjectsMinimumRole prop', () => {
      expect(findEnableRoleSelect().props('value')).toBe(ACCESS_LEVEL_OWNER_INTEGER);
    });

    it('passes the correct prop', () => {
      createWrapper({ props: { enableOnProjectsMinimumRole: ACCESS_LEVEL_OWNER_INTEGER } });

      expect(findEnableRoleSelect().props('value')).toBe(ACCESS_LEVEL_OWNER_INTEGER);
    });

    describe('role selection interactions', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('emits enable-role-change event when enable role is changed', () => {
        findEnableRoleSelect().vm.$emit('change', ACCESS_LEVEL_OWNER_INTEGER);

        expect(wrapper.emitted('enable-role-change')).toHaveLength(1);
        expect(wrapper.emitted('enable-role-change')[0]).toEqual([ACCESS_LEVEL_OWNER_INTEGER]);
      });
    });
  });

  describe('manage role selector', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders manage role select with correct options', () => {
      expect(findManageRoleSelect().props('options')).toEqual([
        { text: 'Maintainer', value: ACCESS_LEVEL_MAINTAINER_INTEGER },
        { text: 'Owner', value: ACCESS_LEVEL_OWNER_INTEGER },
      ]);
    });

    describe('when isAdminInstanceDuoHome is true', () => {
      beforeEach(() => {
        createWrapper({ provide: { isAdminInstanceDuoHome: true } });
      });

      it('includes Admin role in manage role options', () => {
        expect(findManageRoleSelect().props('options')).toEqual([
          { text: 'Maintainer', value: ACCESS_LEVEL_MAINTAINER_INTEGER },
          { text: 'Owner', value: ACCESS_LEVEL_OWNER_INTEGER },
          { text: 'Admin', value: ACCESS_LEVEL_ADMIN_INTEGER },
        ]);
      });
    });

    it('sets initial value from manageMinimumRole prop', () => {
      expect(findManageRoleSelect().props('value')).toBe(ACCESS_LEVEL_MAINTAINER_INTEGER);
    });

    describe('role selection interactions', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('emits manage-role-change event when manage role is changed', () => {
        findManageRoleSelect().vm.$emit('change', ACCESS_LEVEL_OWNER_INTEGER);

        expect(wrapper.emitted('manage-role-change')).toHaveLength(1);
        expect(wrapper.emitted('manage-role-change')[0]).toEqual([ACCESS_LEVEL_OWNER_INTEGER]);
      });
    });

    describe('with custom prop values', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            manageMinimumRole: ACCESS_LEVEL_OWNER_INTEGER,
          },
        });
      });

      it('sets initial value from custom prop', () => {
        expect(findManageRoleSelect().props('value')).toBe(ACCESS_LEVEL_OWNER_INTEGER);
      });
    });
  });

  describe('execute role selector', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders execute role select with correct options', () => {
      expect(findExecuteRoleSelect().props('options')).toEqual([
        { text: 'Developer', value: ACCESS_LEVEL_DEVELOPER_INTEGER },
        { text: 'Maintainer', value: ACCESS_LEVEL_MAINTAINER_INTEGER },
        { text: 'Owner', value: ACCESS_LEVEL_OWNER_INTEGER },
      ]);
    });

    describe('when isAdminInstanceDuoHome is true', () => {
      beforeEach(() => {
        createWrapper({ provide: { isAdminInstanceDuoHome: true } });
      });

      it('includes Admin role in manage role options', () => {
        expect(findExecuteRoleSelect().props('options')).toEqual([
          { text: 'Developer', value: ACCESS_LEVEL_DEVELOPER_INTEGER },
          { text: 'Maintainer', value: ACCESS_LEVEL_MAINTAINER_INTEGER },
          { text: 'Owner', value: ACCESS_LEVEL_OWNER_INTEGER },
          { text: 'Admin', value: ACCESS_LEVEL_ADMIN_INTEGER },
        ]);
      });
    });

    it('sets initial value from executeMinimumRole prop', () => {
      expect(findExecuteRoleSelect().props('value')).toBe(ACCESS_LEVEL_DEVELOPER_INTEGER);
    });

    it('emits execute-role-change event when execute role is changed', () => {
      findExecuteRoleSelect().vm.$emit('change', ACCESS_LEVEL_MAINTAINER_INTEGER);

      expect(wrapper.emitted('execute-role-change')).toHaveLength(1);
      expect(wrapper.emitted('execute-role-change')[0]).toEqual([ACCESS_LEVEL_MAINTAINER_INTEGER]);
    });

    describe('onEnableRoleSelect', () => {
      it('emits the emits event', () => {
        findEnableRoleSelect().vm.$emit('change', ACCESS_LEVEL_MAINTAINER_INTEGER);

        expect(wrapper.emitted('enable-role-change')).toEqual([[ACCESS_LEVEL_MAINTAINER_INTEGER]]);
      });
    });

    describe('onManageRoleSelect', () => {
      it('emits the emits event', () => {
        findManageRoleSelect().vm.$emit('change', ACCESS_LEVEL_OWNER_INTEGER);

        expect(wrapper.emitted('manage-role-change')).toEqual([[ACCESS_LEVEL_OWNER_INTEGER]]);
      });
    });

    describe('onExecuteRoleSelect', () => {
      it('emits the emits event', () => {
        findExecuteRoleSelect().vm.$emit('change', ACCESS_LEVEL_MAINTAINER_INTEGER);

        expect(wrapper.emitted('execute-role-change')).toEqual([[ACCESS_LEVEL_MAINTAINER_INTEGER]]);
      });
    });

    describe('with custom prop values', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            executeMinimumRole: ACCESS_LEVEL_MAINTAINER_INTEGER,
          },
        });
      });

      it('sets initial value from custom prop', () => {
        expect(findExecuteRoleSelect().props('value')).toBe(ACCESS_LEVEL_MAINTAINER_INTEGER);
      });
    });
  });
});
