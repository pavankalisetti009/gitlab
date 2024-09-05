import { logError } from '~/lib/logger';
import { s__ } from '~/locale';
import { graphqlClient } from '~/members/graphql_client';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import GroupPendingMemberApprovalsQuery from '../graphql/group_pending_member_approvals.query.graphql';
import ProjectPendingMemberApprovalsQuery from '../graphql/project_pending_member_approvals.query.graphql';
import { invalidate } from '../services/promotion_request_list_invalidation_service';
import { UPDATE_TOTAL_ITEMS } from './mutation_types';

/** @type {import('vuex').Action<any, any>} */
export const invalidatePromotionRequestsData = ({ dispatch }, { group, project }) => {
  invalidate();
  dispatch('refetchPromotionRequestsCount', { group, project });
};

/** @type {import('vuex').Action<any, any>} */
export const refetchPromotionRequestsCount = async ({ commit }, { group, project }) => {
  const isProject = Boolean(project.path);
  const query = isProject ? ProjectPendingMemberApprovalsQuery : GroupPendingMemberApprovalsQuery;

  await graphqlClient
    .query({
      query,
      variables: {
        fullPath: project.path || group.path,
        first: 0,
      },
      fetchPolicy: 'network-only',
    })
    .then((response) => {
      const count = isProject
        ? response.data.project.pendingMemberApprovals.count
        : response.data.group.pendingMemberApprovals.count;

      commit(UPDATE_TOTAL_ITEMS, count);
    })
    .catch((error) => {
      logError(s__('PromotionRequests|Error fetching promotion requests count'), error);
      Sentry.captureException(error);
    });
};
