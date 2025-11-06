export const mockDataWithPool = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-02-02T18:45:32Z',

      startDate: '2025-08-01',
      endDate: '2025-08-31',

      usersUsage: {
        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/42',
              username: 'alice_johnson',
              name: 'Alice Johnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',

              usage: {
                creditsUsed: 1000,
                totalCredits: 1000,
                monthlyCommitmentCreditsUsed: 500,
                monthlyWaiverCreditsUsed: 212,
                overageCreditsUsed: 100,
              },

              events: {
                nodes: [
                  {
                    timestamp: '2025-01-21T16:42:38Z',
                    eventType: 'Duo Workflow - Code Generation',
                    location: {
                      __typename: 'Project',
                      id: '1',
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 44000,
                  },
                  {
                    timestamp: '2025-01-21T16:41:15Z',
                    eventType: 'Duo Chat - Extended Session',
                    location: {
                      __typename: 'Group',
                      id: '2',
                      name: 'group-app',
                      webUrl: 'http://localhost:3000/group-app',
                    },
                    creditsUsed: 62000,
                  },
                  {
                    timestamp: '2025-01-21T16:40:22Z',
                    eventType: 'Code Suggestions - Completion',
                    location: {
                      __typename: 'Project',
                      id: '1',
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 0,
                  },
                  {
                    timestamp: '2025-01-21T16:39:45Z',
                    eventType: 'Duo Workflow - Test Generation',
                    location: {
                      __typename: 'Group',
                      id: '2',
                      name: 'group-app',
                      webUrl: 'http://localhost:3000/group-app',
                    },
                    creditsUsed: null,
                  },
                  {
                    timestamp: '2025-01-21T16:38:12Z',
                    eventType: 'Code Review Assistant',
                    location: {
                      __typename: 'Project',
                      id: '1',
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 82,
                  },
                  {
                    timestamp: '2025-01-21T16:37:33Z',
                    eventType: 'Duo Chat',
                    location: null,
                    creditsUsed: 55,
                  },
                  {
                    timestamp: '2025-01-21T16:36:58Z',
                    eventType: 'Code Suggestions - Refactoring',
                    location: {
                      __typename: 'Project',
                      id: '1',
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 26,
                  },
                  {
                    timestamp: '2025-01-21T16:35:41Z',
                    eventType: 'Vulnerability Explanation',
                    location: {
                      __typename: 'Group',
                      id: '2',
                      name: 'group-app',
                      webUrl: 'http://localhost:3000/group-app',
                    },
                    creditsUsed: 74,
                  },
                  {
                    timestamp: '2025-01-21T16:34:27Z',
                    eventType: 'Duo Workflow - Code Generation',
                    location: {
                      __typename: 'Project',
                      id: '1',
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 51,
                  },
                  {
                    timestamp: '2025-01-21T16:33:05Z',
                    eventType: 'Duo Workflow - Code Generation',
                    location: {
                      __typename: 'Project',
                      id: '1',
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 70,
                  },
                  {
                    timestamp: '2025-01-21T16:31:52Z',
                    eventType: 'Duo Workflow - Code Generation',
                    location: {
                      __typename: 'Project',
                      id: '1',
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 15,
                  },
                ],
                pageInfo: {
                  hasNextPage: true,
                  hasPreviousPage: false,
                  startCursor: null,
                  endCursor: 'endCursor',
                  __typename: 'PageInfo',
                },
              },
            },
          ],
        },
      },
    },
  },
};

export const mockDataWithoutPool = {
  data: {
    subscriptionUsage: {
      ...mockDataWithPool.data.subscriptionUsage,

      monthlyCommitment: {
        creditsUsed: 0,
        totalCredits: 0,
      },

      usersUsage: {
        users: {
          ...mockDataWithPool.data.subscriptionUsage.usersUsage.users,
          nodes: [
            {
              ...mockDataWithPool.data.subscriptionUsage.usersUsage.users.nodes[0],
              usage: {
                ...mockDataWithPool.data.subscriptionUsage.usersUsage.users.nodes[0].usage,
                monthlyCommitmentCreditsUsed: 0,
              },
            },
          ],
        },
      },
    },
  },
};

export const mockEmptyData = {
  data: {
    subscriptionUsage: {
      ...mockDataWithPool.data.subscriptionUsage,

      monthlyCommitment: {
        creditsUsed: 0,
        totalCredits: 1000,
      },

      usersUsage: {
        users: {
          ...mockDataWithPool.data.subscriptionUsage.usersUsage.users,
          nodes: [
            {
              ...mockDataWithPool.data.subscriptionUsage.usersUsage.users.nodes[0],

              usage: {
                creditsUsed: 0,
                totalCredits: 0,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
              },

              events: {
                nodes: [],
                pageInfo: {
                  hasNextPage: false,
                  hasPreviousPage: false,
                  startCursor: null,
                  endCursor: null,
                  __typename: 'PageInfo',
                },
              },
            },
          ],
        },
      },
    },
  },
};

export const mockNullData = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-31T12:55:21Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      usersUsage: {
        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/42',
              username: 'alice_johnson',
              name: 'Alice Johnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                creditsUsed: null,
                monthlyCommitmentCreditsUsed: null,
                overageCreditsUsed: null,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
          ],
          __typename: 'GitlabSubscriptionUsageUserConnection',
        },
        __typename: 'GitlabSubscriptionUsageUsersUsage',
      },
      __typename: 'GitlabSubscriptionUsage',
    },
  },
};
