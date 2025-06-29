import { s__ } from '~/locale';
import { createTokenConfig } from '~/admin/users/constants';
import AdminRoleToken from './components/admin_role_token.vue';

export {
  getFilterTokenConfigs,
  SOLO_OWNED_ORGANIZATIONS_EMPTY,
  I18N_USER_ACTIONS,
  SOLO_OWNED_ORGANIZATIONS_REQUESTED_COUNT,
} from '~/admin/users/constants';

export const ACCESS_LEVEL_OPTIONS = [
  { value: 'admins', title: s__('AdminUsers|Administrator') },
  { value: 'auditors', title: s__('AdminUsers|Auditor') },
  { value: 'external', title: s__('AdminUsers|External') },
];

export const getStandardTokenConfigs = ({ customRoles, customAdminRoles }) => {
  const configs = [];
  // Add the admin role token config if the license allows custom roles (Ultimate-only feature) and
  // the custom_admin_roles feature flag is on.
  if (customRoles && customAdminRoles) {
    configs.push(
      createTokenConfig({
        type: 'admin_role_id',
        title: s__('MemberRole|Admin role'),
        token: AdminRoleToken,
      }),
    );
  }

  return configs;
};
