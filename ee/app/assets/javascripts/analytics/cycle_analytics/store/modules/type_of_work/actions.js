import { getTypeOfWorkTopLabels } from 'ee/api/analytics_api';
import { __ } from '~/locale';
import { throwIfUserForbidden, checkForDataError, alertErrorIfStatusNotOk } from '../../../utils';
import * as types from './mutation_types';

export const receiveTopRankedGroupLabelsSuccess = ({ commit }, data) => {
  commit(types.RECEIVE_TOP_RANKED_GROUP_LABELS_SUCCESS, data);
};

export const receiveTopRankedGroupLabelsError = ({ commit }, error) => {
  alertErrorIfStatusNotOk({
    error,
    message: __('There was an error fetching the top labels for the selected group'),
  });
  commit(types.RECEIVE_TOP_RANKED_GROUP_LABELS_ERROR, error);
};

export const fetchTopRankedGroupLabels = ({ dispatch, commit, state, rootGetters }) => {
  commit(types.REQUEST_TOP_RANKED_GROUP_LABELS);
  const {
    namespacePath,
    cycleAnalyticsRequestParams: {
      project_ids,
      created_after,
      created_before,
      author_username,
      milestone_title,
      assignee_username,
    },
  } = rootGetters;
  const { subject } = state;

  return getTypeOfWorkTopLabels(namespacePath, {
    subject,
    project_ids,
    created_after,
    created_before,
    author_username,
    milestone_title,
    assignee_username,
  })
    .then(checkForDataError)
    .then(({ data }) => dispatch('receiveTopRankedGroupLabelsSuccess', data))
    .catch((error) => {
      throwIfUserForbidden(error);
      return dispatch('receiveTopRankedGroupLabelsError', error);
    });
};

export const setTasksByTypeFilters = ({ commit }, data) => {
  commit(types.SET_TASKS_BY_TYPE_FILTERS, data);
};
