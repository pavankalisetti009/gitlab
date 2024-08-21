export const mockQueryResult = {
  data: {
    project: {
      id: 'gid://gitlab/Project/7',
      issues: {
        nodes: [
          {
            id: 'gid://gitlab/Issue/646',
            title: 'Issue created from feature_flag.flagd.evaluation.reason',
            state: 'opened',
            description:
              '[Metric details](http://gdk.test:3443/flightjs/Flight/-/metrics/feature_flag.flagd.evaluation.reason?type=Sum\u0026date_range=custom\u0026date_start=2024-08-16T13:43:15.708Z\u0026date_end=2024-08-16T14:43:15.708Z) \\\nName: `feature_flag.flagd.evaluation.reason` \\\nType: `Sum` \\\nTimeframe: `Fri, 16 Aug 2024 13:43:15 GMT - Fri, 16 Aug 2024 14:43:15 GMT`',
            confidential: false,
            createdAt: '2024-08-16T14:47:21Z',
            closedAt: null,
            webUrl: 'http://gdk.test:3443/flightjs/Flight/-/issues/39',
            dueDate: null,
            reference: '#39',
            weight: null,
            assignees: {
              nodes: [],
              __typename: 'UserCoreConnection',
            },
            milestone: null,
            __typename: 'Issue',
          },
          {
            id: 'gid://gitlab/Issue/645',
            title: 'Issue created from app.ads.ad_requests',
            state: 'opened',
            description:
              '[Metric details](http://gdk.test:3443/flightjs/Flight/-/metrics/app.ads.ad_requests?type=Sum\u0026date_range=custom\u0026group_by_fn=sum\u0026group_by_attrs[]=app.ads.ad_request_type\u0026group_by_attrs[]=app.ads.ad_response_type\u0026date_start=2024-08-05T09:03:33.443Z\u0026date_end=2024-08-05T10:03:33.443Z) \\\nName: `app.ads.ad_requests` \\\nType: `Sum` \\\nTimeframe: `Mon, 05 Aug 2024 09:03:33 GMT - Mon, 05 Aug 2024 10:03:33 GMT` \\',
            confidential: false,
            createdAt: '2024-08-05T10:04:39Z',
            closedAt: null,
            webUrl: 'http://gdk.test:3443/flightjs/Flight/-/issues/38',
            dueDate: null,
            reference: '#38',
            weight: null,
            assignees: {
              nodes: [],
              __typename: 'UserCoreConnection',
            },
            milestone: null,
            __typename: 'Issue',
          },
        ],
        __typename: 'IssueConnection',
      },
      __typename: 'Project',
    },
  },
};
