import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LdapSyncItem from 'ee/roles_and_permissions/components/ldap_sync/ldap_sync_item.vue';
import { ldapAdminRoleLinks } from '../../mock_data';

describe('LdapSyncItem component', () => {
  let wrapper;

  const createWrapper = ({ roleLink = ldapAdminRoleLinks[0] } = {}) => {
    wrapper = shallowMountExtended(LdapSyncItem, {
      propsData: { roleLink },
    });
  };

  const findDts = () => wrapper.findAll('dt');
  const findDds = () => wrapper.findAll('dd');
  const findDeleteButton = () => wrapper.findComponent(GlButton);

  describe.each`
    roleLink                 | syncMethodLabel   | syncMethodValue                            | expectedServer | expectedRole
    ${ldapAdminRoleLinks[0]} | ${'User filter:'} | ${'cn=group1,ou=groups,dc=example,dc=com'} | ${'LDAP'}      | ${'Custom admin role 1'}
    ${ldapAdminRoleLinks[1]} | ${'Group cn:'}    | ${'group2'}                                | ${'LDAP alt'}  | ${'Custom admin role 2'}
  `(
    'for role link $roleLink.id',
    ({ roleLink, syncMethodLabel, syncMethodValue, expectedServer, expectedRole }) => {
      beforeEach(() => createWrapper({ roleLink }));

      it('shows server label', () => {
        expect(findDts().at(0).text()).toBe('Server:');
      });

      it('shows server name', () => {
        expect(findDds().at(0).text()).toBe(expectedServer);
      });

      it('shows sync method label', () => {
        expect(findDts().at(1).text()).toBe(syncMethodLabel);
      });

      it('shows sync method value', () => {
        expect(findDds().at(1).text()).toBe(syncMethodValue);
      });

      it('shows custom admin role label', () => {
        expect(findDts().at(2).text()).toBe('Custom admin role:');
      });

      it('shows custom admin role name', () => {
        expect(findDds().at(2).text()).toBe(expectedRole);
      });

      describe('delete button', () => {
        it('shows button', () => {
          expect(findDeleteButton().attributes('aria-label')).toBe('Remove sync');
          expect(findDeleteButton().props()).toMatchObject({
            variant: 'danger',
            category: 'secondary',
            icon: 'remove',
          });
        });

        it('emits delete event when clicked', () => {
          findDeleteButton().vm.$emit('click');

          expect(wrapper.emitted('delete')).toHaveLength(1);
        });
      });
    },
  );
});
