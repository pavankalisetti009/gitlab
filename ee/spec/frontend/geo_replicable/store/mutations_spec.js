import * as types from 'ee/geo_replicable/store/mutation_types';
import mutations from 'ee/geo_replicable/store/mutations';
import createState from 'ee/geo_replicable/store/state';
import { MOCK_GRAPHQL_REGISTRY, MOCK_REPLICABLE_TYPE } from '../mock_data';

describe('GeoReplicable Store Mutations', () => {
  let state;
  beforeEach(() => {
    state = createState({
      replicableType: MOCK_REPLICABLE_TYPE,
      graphqlFieldName: MOCK_GRAPHQL_REGISTRY,
    });
  });

  describe.each`
    mutation                                                | loadingBefore | loadingAfter
    ${types.REQUEST_INITIATE_ALL_REPLICABLE_ACTION}         | ${false}      | ${true}
    ${types.RECEIVE_INITIATE_ALL_REPLICABLE_ACTION_SUCCESS} | ${true}       | ${false}
    ${types.RECEIVE_INITIATE_ALL_REPLICABLE_ACTION_ERROR}   | ${true}       | ${false}
    ${types.REQUEST_INITIATE_REPLICABLE_ACTION}             | ${false}      | ${true}
    ${types.RECEIVE_INITIATE_REPLICABLE_ACTION_SUCCESS}     | ${true}       | ${false}
    ${types.RECEIVE_INITIATE_REPLICABLE_ACTION_ERROR}       | ${true}       | ${false}
  `(`Sync Mutations:`, ({ mutation, loadingBefore, loadingAfter }) => {
    describe(`${mutation}`, () => {
      it(`sets isLoading to ${loadingAfter}`, () => {
        state.isLoading = loadingBefore;

        mutations[mutation](state);
        expect(state.isLoading).toBe(loadingAfter);
      });
    });
  });
});
