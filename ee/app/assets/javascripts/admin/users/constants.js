import { s__ } from '~/locale';

export {
  getFilterTokenConfigs,
  getStandardTokenConfigs,
  SOLO_OWNED_ORGANIZATIONS_EMPTY,
  I18N_USER_ACTIONS,
  SOLO_OWNED_ORGANIZATIONS_REQUESTED_COUNT,
} from '~/admin/users/constants';

export const ACCESS_LEVEL_OPTIONS = [
  { value: 'admins', title: s__('AdminUsers|Administrator') },
  { value: 'auditors', title: s__('AdminUsers|Auditor') },
  { value: 'external', title: s__('AdminUsers|External') },
];
