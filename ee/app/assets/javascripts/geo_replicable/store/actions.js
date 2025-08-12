import { getGraphqlClient } from 'ee/geo_shared/graphql/geo_client';
import { createAlert } from '~/alert';
import { s__, __, sprintf } from '~/locale';
import toast from '~/vue_shared/plugins/global_toast';
import replicableTypeUpdateMutation from 'ee/geo_shared/graphql/replicable_type_update_mutation.graphql';
import replicableTypeBulkUpdateMutation from '../graphql/replicable_type_bulk_update_mutation.graphql';
import * as types from './mutation_types';

// Initiate All Replicable Action
export const requestInitiateAllReplicableAction = ({ commit }) =>
  commit(types.REQUEST_INITIATE_ALL_REPLICABLE_ACTION);
export const receiveInitiateAllReplicableActionSuccess = (
  { state, commit, dispatch },
  { action },
) => {
  toast(
    sprintf(s__('Geo|All %{replicableType} are being scheduled for %{action}'), {
      replicableType: state.titlePlural,
      action: action.replace('_', ' '),
    }),
  );
  commit(types.RECEIVE_INITIATE_ALL_REPLICABLE_ACTION_SUCCESS);
  dispatch('fetchReplicableItems');
};
export const receiveInitiateAllReplicableActionError = ({ state, commit }, { action }) => {
  createAlert({
    message: sprintf(
      s__('Geo|There was an error scheduling action %{action} for %{replicableType}'),
      {
        replicableType: state.titlePlural,
        action: action.replace('_', ' '),
      },
    ),
  });
  commit(types.RECEIVE_INITIATE_ALL_REPLICABLE_ACTION_ERROR);
};

export const initiateAllReplicableAction = ({ state, dispatch }, { action }) => {
  dispatch('requestInitiateAllReplicableAction');

  const client = getGraphqlClient(state.geoCurrentSiteId, state.geoTargetSiteId);

  client
    .mutate({
      mutation: replicableTypeBulkUpdateMutation,
      variables: {
        action: action.toUpperCase(),
        registryClass: state.graphqlMutationRegistryClass,
      },
    })
    .then(() => dispatch('receiveInitiateAllReplicableActionSuccess', { action }))
    .catch(() => {
      dispatch('receiveInitiateAllReplicableActionError', { action });
    });
};

// Initiate Replicable Action
export const requestInitiateReplicableAction = ({ commit }) =>
  commit(types.REQUEST_INITIATE_REPLICABLE_ACTION);
export const receiveInitiateReplicableActionSuccess = ({ commit, dispatch }, { name, action }) => {
  toast(sprintf(__('%{name} is scheduled for %{action}'), { name, action }));
  commit(types.RECEIVE_INITIATE_REPLICABLE_ACTION_SUCCESS);
  dispatch('fetchReplicableItems');
};
export const receiveInitiateReplicableActionError = ({ commit }, { name }) => {
  createAlert({
    message: sprintf(__('There was an error syncing project %{name}'), { name }),
  });
  commit(types.RECEIVE_INITIATE_REPLICABLE_ACTION_ERROR);
};

export const initiateReplicableAction = ({ state, dispatch }, { registryId, name, action }) => {
  dispatch('requestInitiateReplicableAction');

  const client = getGraphqlClient(state.geoCurrentSiteId, state.geoTargetSiteId);

  client
    .mutate({
      mutation: replicableTypeUpdateMutation,
      variables: {
        action: action.toUpperCase(),
        registryId,
      },
    })
    .then(() => dispatch('receiveInitiateReplicableActionSuccess', { name, action }))
    .catch(() => {
      dispatch('receiveInitiateReplicableActionError', { name });
    });
};
