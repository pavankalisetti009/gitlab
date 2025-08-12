import { ACTION_TYPES } from 'ee/geo_replicable/constants';
import replicableTypeUpdateMutation from 'ee/geo_shared/graphql/replicable_type_update_mutation.graphql';
import replicableTypeBulkUpdateMutation from 'ee/geo_replicable/graphql/replicable_type_bulk_update_mutation.graphql';
import * as actions from 'ee/geo_replicable/store/actions';
import * as types from 'ee/geo_replicable/store/mutation_types';
import createState from 'ee/geo_replicable/store/state';
import testAction from 'helpers/vuex_action_helper';
import { createAlert } from '~/alert';
import toast from '~/vue_shared/plugins/global_toast';
import { MOCK_REPLICABLE_TYPE, MOCK_GRAPHQL_REGISTRY_CLASS } from '../mock_data';

jest.mock('~/alert');
jest.mock('~/vue_shared/plugins/global_toast');

const mockGeoGqClient = { query: jest.fn(), mutate: jest.fn() };
jest.mock('ee/geo_shared/graphql/geo_client', () => ({
  ...jest.requireActual('ee/geo_shared/graphql/geo_client'),
  getGraphqlClient: jest.fn().mockImplementation(() => mockGeoGqClient),
}));

describe('GeoReplicable Store Actions', () => {
  let state;

  beforeEach(() => {
    state = createState({
      titlePlural: MOCK_REPLICABLE_TYPE,
      graphqlMutationRegistryClass: MOCK_GRAPHQL_REGISTRY_CLASS,
      geoCurrentSiteId: null,
      geoTargetSiteId: null,
    });
  });

  // All Replicable Action

  describe('requestInitiateAllReplicableAction', () => {
    it('should commit mutation REQUEST_INITIATE_ALL_REPLICABLE_ACTION', async () => {
      await testAction(
        actions.requestInitiateAllReplicableAction,
        null,
        state,
        [{ type: types.REQUEST_INITIATE_ALL_REPLICABLE_ACTION }],
        [],
      );
    });
  });

  describe('receiveInitiateAllReplicableActionSuccess', () => {
    it('should commit mutation RECEIVE_INITIATE_ALL_REPLICABLE_ACTION_SUCCESS and call fetchReplicableItems and toast', async () => {
      await testAction(
        actions.receiveInitiateAllReplicableActionSuccess,
        { action: ACTION_TYPES.RESYNC_ALL },
        state,
        [{ type: types.RECEIVE_INITIATE_ALL_REPLICABLE_ACTION_SUCCESS }],
        [{ type: 'fetchReplicableItems' }],
      );

      expect(toast).toHaveBeenCalledTimes(1);
      toast.mockClear();
    });
  });

  describe('receiveInitiateAllReplicableActionError', () => {
    it('should commit mutation RECEIVE_INITIATE_ALL_REPLICABLE_ACTION_ERROR', async () => {
      await testAction(
        actions.receiveInitiateAllReplicableActionError,
        { action: ACTION_TYPES.RESYNC_ALL },
        state,
        [{ type: types.RECEIVE_INITIATE_ALL_REPLICABLE_ACTION_ERROR }],
        [],
      );

      expect(createAlert).toHaveBeenCalledTimes(1);
    });
  });

  describe('All Replicable Action', () => {
    const action = ACTION_TYPES.RESYNC_ALL;

    describe('initiateAllReplicableAction', () => {
      describe('on success', () => {
        beforeEach(() => {
          jest.spyOn(mockGeoGqClient, 'mutate').mockResolvedValue({});
        });

        it('should call mockGeoClient with correct parameters and success actions', async () => {
          await testAction(
            actions.initiateAllReplicableAction,
            { action },
            state,
            [],
            [
              { type: 'requestInitiateAllReplicableAction' },
              {
                type: 'receiveInitiateAllReplicableActionSuccess',
                payload: { action },
              },
            ],
          );
        });
      });

      describe('on error', () => {
        beforeEach(() => {
          jest.spyOn(mockGeoGqClient, 'mutate').mockRejectedValue({});
        });

        it('should call mockGeoClient with correct parameters and error actions', async () => {
          await testAction(
            actions.initiateAllReplicableAction,
            { action },
            state,
            [],
            [
              { type: 'requestInitiateAllReplicableAction' },
              {
                type: 'receiveInitiateAllReplicableActionError',
                payload: { action },
              },
            ],
          );

          expect(mockGeoGqClient.mutate).toHaveBeenCalledWith({
            mutation: replicableTypeBulkUpdateMutation,
            variables: {
              action: action.toUpperCase(),
              registryClass: MOCK_GRAPHQL_REGISTRY_CLASS,
            },
          });
        });
      });
    });
  });

  // Single Replicable Action

  describe('requestInitiateReplicableAction', () => {
    it('should commit mutation REQUEST_INITIATE_REPLICABLE_ACTION', async () => {
      await testAction(
        actions.requestInitiateReplicableAction,
        null,
        state,
        [{ type: types.REQUEST_INITIATE_REPLICABLE_ACTION }],
        [],
      );
    });
  });

  describe('receiveInitiateReplicableActionSuccess', () => {
    it('should commit mutation RECEIVE_INITIATE_REPLICABLE_ACTION_SUCCESS and call fetchReplicableItems and toast', async () => {
      await testAction(
        actions.receiveInitiateReplicableActionSuccess,
        { action: ACTION_TYPES.RESYNC, name: 'test' },
        state,
        [{ type: types.RECEIVE_INITIATE_REPLICABLE_ACTION_SUCCESS }],
        [{ type: 'fetchReplicableItems' }],
      );
      expect(toast).toHaveBeenCalledTimes(1);
      toast.mockClear();
    });
  });

  describe('receiveInitiateReplicableActionError', () => {
    it('should commit mutation RECEIVE_INITIATE_REPLICABLE_ACTION_ERROR', async () => {
      await testAction(
        actions.receiveInitiateReplicableActionError,
        { action: ACTION_TYPES.RESYNC, registryId: 1, name: 'test' },
        state,
        [{ type: types.RECEIVE_INITIATE_REPLICABLE_ACTION_ERROR }],
        [],
      );
      expect(createAlert).toHaveBeenCalledTimes(1);
    });
  });

  describe('Replicable Action', () => {
    const action = ACTION_TYPES.RESYNC;
    const registryId = 1;
    const name = 'test';

    describe('initiateReplicableAction', () => {
      describe('on success', () => {
        beforeEach(() => {
          jest.spyOn(mockGeoGqClient, 'mutate').mockResolvedValue({});
        });

        it('should call mockGeoClient with correct parameters and success actions', async () => {
          await testAction(
            actions.initiateReplicableAction,
            { registryId, name, action },
            state,
            [],
            [
              { type: 'requestInitiateReplicableAction' },
              {
                type: 'receiveInitiateReplicableActionSuccess',
                payload: { name, action },
              },
            ],
          );

          expect(mockGeoGqClient.mutate).toHaveBeenCalledWith({
            mutation: replicableTypeUpdateMutation,
            variables: {
              action: action.toUpperCase(),
              registryId,
            },
          });
        });
      });

      describe('on error', () => {
        beforeEach(() => {
          jest.spyOn(mockGeoGqClient, 'mutate').mockRejectedValue({});
        });

        it('should call mockGeoClient with correct parameters and error actions', async () => {
          await testAction(
            actions.initiateReplicableAction,
            { registryId, name, action },
            state,
            [],
            [
              { type: 'requestInitiateReplicableAction' },
              {
                type: 'receiveInitiateReplicableActionError',
                payload: { name },
              },
            ],
          );

          expect(mockGeoGqClient.mutate).toHaveBeenCalledWith({
            mutation: replicableTypeUpdateMutation,
            variables: {
              action: action.toUpperCase(),
              registryId,
            },
          });
        });
      });
    });
  });
});
