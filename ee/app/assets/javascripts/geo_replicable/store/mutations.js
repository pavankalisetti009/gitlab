import * as types from './mutation_types';

export default {
  [types.REQUEST_INITIATE_ALL_REPLICABLE_ACTION](state) {
    state.isLoading = true;
  },
  [types.RECEIVE_INITIATE_ALL_REPLICABLE_ACTION_SUCCESS](state) {
    state.isLoading = false;
  },
  [types.RECEIVE_INITIATE_ALL_REPLICABLE_ACTION_ERROR](state) {
    state.isLoading = false;
  },
  [types.REQUEST_INITIATE_REPLICABLE_ACTION](state) {
    state.isLoading = true;
  },
  [types.RECEIVE_INITIATE_REPLICABLE_ACTION_SUCCESS](state) {
    state.isLoading = false;
  },
  [types.RECEIVE_INITIATE_REPLICABLE_ACTION_ERROR](state) {
    state.isLoading = false;
  },
};
