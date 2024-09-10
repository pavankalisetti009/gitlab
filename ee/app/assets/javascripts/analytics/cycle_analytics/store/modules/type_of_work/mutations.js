import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { TASKS_BY_TYPE_FILTERS } from '../../../constants';
import { toggleSelectedLabel } from '../../../utils';
import * as types from './mutation_types';

export default {
  [types.REQUEST_TOP_RANKED_GROUP_LABELS](state) {
    state.isLoading = true;
    state.topRankedLabels = [];
    state.selectedLabels = [];
    state.errorCode = null;
    state.errorMessage = '';
  },
  [types.RECEIVE_TOP_RANKED_GROUP_LABELS_SUCCESS](state, data = []) {
    state.isLoading = false;
    state.topRankedLabels = data.map(convertObjectPropsToCamelCase);
    state.selectedLabels = data.map(convertObjectPropsToCamelCase);
    state.errorCode = null;
    state.errorMessage = '';
  },
  [types.RECEIVE_TOP_RANKED_GROUP_LABELS_ERROR](state, { errorCode = null, message = '' } = {}) {
    state.isLoading = false;
    state.topRankedLabels = [];
    state.selectedLabels = [];
    state.errorCode = errorCode;
    state.errorMessage = message;
  },
  [types.SET_TASKS_BY_TYPE_FILTERS](state, { filter, value }) {
    const { selectedLabels } = state;
    switch (filter) {
      case TASKS_BY_TYPE_FILTERS.LABEL: {
        state.selectedLabels = toggleSelectedLabel({ selectedLabels, value });
        break;
      }
      case TASKS_BY_TYPE_FILTERS.SUBJECT: {
        state.subject = value;
        break;
      }
      default:
        break;
    }
  },
};
