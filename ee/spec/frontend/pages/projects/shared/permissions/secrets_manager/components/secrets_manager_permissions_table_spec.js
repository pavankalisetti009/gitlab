import { GlTab, GlTableLite } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import PermissionsTable from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_table.vue';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
} from 'ee/pages/projects/shared/permissions/secrets_manager/constants';
import {
  OWNER_PERMISSION_NODE,
  ROLE_PERMISSION_NODE,
  GROUP_PERMISSION_NODE,
  USER_PERMISSION_NODE,
} from '../mock_data';

describe('SecretsManagerPermissionsSettings', () => {
  let wrapper;

  const createComponent = ({ props, mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(PermissionsTable, {
      propsData: {
        items: [],
        permissionCategory: PERMISSION_CATEGORY_USER,
        ...props,
      },
    });
  };

  const findTab = () => wrapper.findComponent(GlTab);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findRowCell = (rowIndex = 0) =>
    findTable().findAll('tbody > tr').at(rowIndex).findAll('td');

  const userFields = [
    { key: 'user', label: 'User' },
    { key: 'role', label: 'Role' },
    { key: 'scope', label: 'Scope' },
    { key: 'access-granted', label: 'Access granted' },
    { key: 'actions', label: 'Actions' },
  ];
  const groupFields = [
    { key: 'group', label: 'Group' },
    { key: 'scope', label: 'Scope' },
    { key: 'access-granted', label: 'Access granted' },
    { key: 'actions', label: 'Actions' },
  ];
  const roleFields = [
    { key: 'role', label: 'Role' },
    { key: 'scope', label: 'Scope' },
    { key: 'access-granted', label: 'Access granted' },
    { key: 'actions', label: 'Actions' },
  ];

  describe.each`
    permissionCategory | tableFields    | title
    ${'USER'}          | ${userFields}  | ${'Users'}
    ${'GROUP'}         | ${groupFields} | ${'Group'}
    ${'ROLE'}          | ${roleFields}  | ${'Roles'}
  `('$permissionCategory table', ({ permissionCategory, tableFields, title }) => {
    beforeEach(() => {
      createComponent({ props: { permissionCategory } });
    });

    it('renders the correct title', () => {
      expect(findTab().attributes('title')).toBe(title);
    });

    it('renders the correct table fields', () => {
      expect(findTable().props('fields')).toMatchObject(tableFields);
    });
  });

  describe('User table', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mountExtended,
        props: {
          items: [USER_PERMISSION_NODE],
          permissionCategory: PERMISSION_CATEGORY_USER,
        },
      });
    });

    it('renders user info', () => {
      expect(findRowCell().at(0).text()).toContain('kristina.moen');
      expect(findRowCell().at(1).text()).toContain('Maintainer');
      expect(findRowCell().at(2).text()).toContain('Read, Delete');
      expect(findRowCell().at(3).text()).toContain('root');
    });
  });

  describe('Group table', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mountExtended,
        props: {
          items: [GROUP_PERMISSION_NODE],
          permissionCategory: PERMISSION_CATEGORY_GROUP,
        },
      });
    });

    it('renders group info', () => {
      expect(findRowCell().at(0).text()).toContain('Toolbox');
      expect(findRowCell().at(1).text()).toContain('Read, Create, Update');
      expect(findRowCell().at(2).text()).toContain('lonnie');
    });
  });

  describe('Role table', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mountExtended,
        props: {
          items: [OWNER_PERMISSION_NODE, ROLE_PERMISSION_NODE],
          permissionCategory: PERMISSION_CATEGORY_ROLE,
        },
      });
    });

    it('renders group info', () => {
      expect(findRowCell().at(0).text()).toContain('Owner');
      expect(findRowCell().at(1).text()).toContain('Create, Read, Update, Delete');
      expect(findRowCell().at(2).text()).toContain('N/A');

      expect(findRowCell(1).at(0).text()).toContain('Reporter');
      expect(findRowCell(1).at(1).text()).toContain('Read, Create');
      expect(findRowCell(1).at(2).text()).toContain('root');
    });
  });
});
