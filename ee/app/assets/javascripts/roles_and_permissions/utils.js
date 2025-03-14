import { intersection } from 'lodash';
import { TYPENAME_MEMBER_ROLE, TYPENAME_ADMIN_MEMBER_ROLE } from '~/graphql_shared/constants';

export const isCustomRole = ({ __typename }) => __typename === TYPENAME_MEMBER_ROLE;
export const isAdminRole = ({ __typename }) => __typename === TYPENAME_ADMIN_MEMBER_ROLE;

export const isPermissionPreselected = (
  { enabledForGroupAccessLevels: groupLevels, enabledForProjectAccessLevels: projectLevels },
  accessLevel,
) => {
  let enabledForAccessLevels;
  if (groupLevels && projectLevels) {
    enabledForAccessLevels = intersection(groupLevels, projectLevels);
  } else {
    enabledForAccessLevels = groupLevels || projectLevels || [];
  }

  return enabledForAccessLevels.includes(accessLevel);
};
