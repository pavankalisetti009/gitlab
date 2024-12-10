import { availableGraphQLProjectActions as availableGraphQLProjectActionsCE } from '~/vue_shared/components/projects_list/utils';
import { ACTION_RESTORE, BASE_ACTIONS } from '~/vue_shared/components/list_actions/constants';

// Exports override for EE
// eslint-disable-next-line import/export
export * from '~/vue_shared/components/projects_list/utils';

// Exports override for EE
// eslint-disable-next-line import/export
export const availableGraphQLProjectActions = ({ userPermissions, markedForDeletionOn }) => {
  const availableActions = availableGraphQLProjectActionsCE({ userPermissions });

  if (userPermissions.removeProject && markedForDeletionOn) {
    availableActions.push(ACTION_RESTORE);
  }

  return availableActions.sort((a, b) => BASE_ACTIONS[a].order - BASE_ACTIONS[b].order);
};
