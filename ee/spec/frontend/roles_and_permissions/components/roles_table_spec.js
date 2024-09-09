import { mountExtended } from 'helpers/vue_test_utils_helper';
import RolesTable from 'ee/roles_and_permissions/components/roles_table.vue';
import RoleActions from 'ee/roles_and_permissions/components/role_actions.vue';
import { mockMemberRoles } from '../mock_data';

describe('Roles table', () => {
  let wrapper;

  const roles = mockMemberRoles.data.namespace.memberRoles.nodes;

  const createComponent = () => {
    wrapper = mountExtended(RolesTable, {
      propsData: { roles },
    });
  };

  const findHeaders = () => wrapper.find('thead').find('tr').findAll('th');
  const findRowCell = ({ row = 0, cell }) =>
    wrapper.findAll('tbody tr').at(row).findAll('td').at(cell);
  const findActions = () => wrapper.findComponent(RoleActions);

  beforeEach(() => {
    createComponent();
  });

  describe('on creation', () => {
    it('renders the header', () => {
      expect(findHeaders().at(0).text()).toBe('ID');
      expect(findHeaders().at(1).text()).toBe('Name');
      expect(findHeaders().at(2).text()).toBe('Description');
      expect(findHeaders().at(3).text()).toBe('Base role');
      expect(findHeaders().at(4).text()).toBe('Custom permissions');
      expect(findHeaders().at(5).text()).toBe('Member count');
      expect(findHeaders().at(6).text()).toBe('Actions');
    });

    it('renders the id', () => {
      expect(findRowCell({ cell: 0 }).text()).toContain('1');
    });

    it('renders the name', () => {
      expect(findRowCell({ cell: 1 }).text()).toContain('Test');
    });

    it.each`
      row  | expectedDescription
      ${0} | ${'Test description'}
      ${1} | ${'No description'}
    `(
      'renders the description "$expectedDescription" for row $row',
      ({ row, expectedDescription }) => {
        expect(findRowCell({ row, cell: 2 }).text()).toBe(expectedDescription);
      },
    );

    it('renders the base access level', () => {
      expect(findRowCell({ cell: 3 }).text()).toContain('Reporter');
    });

    it('renders the permissions', () => {
      expect(findRowCell({ cell: 4 }).text()).toContain('Read code');
      expect(findRowCell({ cell: 4 }).text()).toContain('Read vulnerability');
    });

    it('renders the member count', () => {
      expect(findRowCell({ cell: 5 }).text()).toContain('0');
    });

    it('renders the actions', () => {
      expect(findActions().exists()).toBe(true);
    });
  });

  describe('when `delete` event is emitted', () => {
    beforeEach(async () => {
      await findActions().vm.$emit('delete');
    });

    it('emits `delete-role` event', () => {
      expect(wrapper.emitted('delete-role')[0][0]).toBe(roles[0]);
    });
  });
});
