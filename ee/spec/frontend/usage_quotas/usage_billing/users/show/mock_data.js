export const mockDataWithPool = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-02-02T18:45:32Z',

      startDate: '2025-08-01',
      endDate: '2025-08-31',

      overage: {
        isAllowed: true,
      },

      poolUsage: {
        totalCredits: 1000,
      },

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
                poolCreditsUsed: 500,
                overageCreditsUsed: 100,
              },

              events: {
                nodes: [
                  {
                    timestamp: '2025-01-21T16:42:38Z',
                    eventType: 'Duo Workflow - Code Generation',
                    location: {
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 44,
                  },
                  {
                    timestamp: '2025-01-21T16:41:15Z',
                    eventType: 'Duo Chat - Extended Session',
                    location: {
                      name: 'group-app',
                      webUrl: 'http://localhost:3000/group-app',
                    },
                    creditsUsed: 62,
                  },
                  {
                    timestamp: '2025-01-21T16:40:22Z',
                    eventType: 'Code Suggestions - Completion',
                    location: {
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 30,
                  },
                  {
                    timestamp: '2025-01-21T16:39:45Z',
                    eventType: 'Duo Workflow - Test Generation',
                    location: {
                      name: 'group-app',
                      webUrl: 'http://localhost:3000/group-app',
                    },
                    creditsUsed: 45,
                  },
                  {
                    timestamp: '2025-01-21T16:38:12Z',
                    eventType: 'Code Review Assistant',
                    location: {
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
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 26,
                  },
                  {
                    timestamp: '2025-01-21T16:35:41Z',
                    eventType: 'Vulnerability Explanation',
                    location: {
                      name: 'group-app',
                      webUrl: 'http://localhost:3000/group-app',
                    },
                    creditsUsed: 74,
                  },
                  {
                    timestamp: '2025-01-21T16:34:27Z',
                    eventType: 'Duo Workflow - Code Generation',
                    location: {
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 51,
                  },
                  {
                    timestamp: '2025-01-21T16:33:05Z',
                    eventType: 'Duo Workflow - Code Generation',
                    location: {
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 70,
                  },
                  {
                    timestamp: '2025-01-21T16:31:52Z',
                    eventType: 'Duo Workflow - Code Generation',
                    location: {
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

      poolUsage: {
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
                poolCreditsUsed: 0,
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

      poolUsage: {
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
                poolCreditsUsed: 0,
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
