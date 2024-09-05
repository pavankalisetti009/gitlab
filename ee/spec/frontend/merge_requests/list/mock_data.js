import { getQueryResponse as getQueryResponseFOSS } from 'jest/merge_requests/list/mock_data';

export { getCountsQueryResponse } from 'jest/merge_requests/list/mock_data';

export const getQueryResponse = {
  data: {
    project: {
      ...getQueryResponseFOSS.data.project,
      mergeRequests: {
        ...getQueryResponseFOSS.data.project.mergeRequests,
        nodes: [
          {
            ...getQueryResponseFOSS.data.project.mergeRequests.nodes[0],
            approved: false,
            approvalsRequired: 0,
            approvalsLeft: 1,
            approvedBy: {
              nodes: [
                {
                  id: 1,
                },
              ],
            },
          },
        ],
      },
    },
  },
};
