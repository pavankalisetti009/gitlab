import { ACTION_TYPES, GEO_SHARED_STATUS_STATES } from './constants';

export const getGraphqlBulkMutationVariables = ({ action, registryClass }) => {
  const variables = {
    registryClass,
    action: null,
    replicationState: null,
  };

  if (action === ACTION_TYPES.RESYNC_ALL_FAILED) {
    variables.action = ACTION_TYPES.RESYNC_ALL.toUpperCase();
    variables.replicationState = GEO_SHARED_STATUS_STATES.FAILED.value.toUpperCase();
  } else {
    variables.action = action.toUpperCase();
  }

  return variables;
};
