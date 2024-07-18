import { cloneDeep } from 'lodash';
import {
  getMemberRole,
  getRoleDropdownItems,
  ldapRole,
} from 'ee/members/components/table/drawer/utils';
import { roleDropdownItems } from 'ee/members/utils';
import { upgradedMember, ldapMember } from '../../../mock_data';

describe('Role details drawer utils', () => {
  describe('getRoleDropdownItems', () => {
    it('returns dropdown items', () => {
      const roles = getRoleDropdownItems(upgradedMember);
      const expectedRoles = roleDropdownItems(upgradedMember);

      expect(roles).toEqual(expectedRoles);
    });

    it('returns LDAP role for LDAP users', () => {
      const roles = getRoleDropdownItems(ldapMember);

      expect(roles.flatten).toContain(ldapRole);
      expect(roles.formatted).toContainEqual({ text: 'LDAP', options: [ldapRole] });
    });
  });

  describe('getMemberRole', () => {
    const roles = getRoleDropdownItems(upgradedMember).flatten;

    it.each(roles)('returns $text role for member', (expectedRole) => {
      const member = cloneDeep(upgradedMember);
      member.accessLevel.integerValue = expectedRole.accessLevel;
      member.accessLevel.memberRoleId = expectedRole.memberRoleId;
      const role = getMemberRole(roles, member);

      expect(role).toBe(expectedRole);
    });

    it('returns LDAP role for LDAP users that are synced to the LDAP settings', () => {
      const role = getMemberRole(roles, ldapMember);

      expect(role).toBe(ldapRole);
    });

    it('returns actual role for LDAP users that have had their role overridden', () => {
      const member = { ...ldapMember, isOverridden: true };
      const role = getMemberRole(roles, member);

      expect(role.text).toBe('custom role 1');
    });
  });
});
