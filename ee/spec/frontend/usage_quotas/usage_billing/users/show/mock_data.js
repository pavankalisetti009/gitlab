import merge from 'lodash/merge';

export const mockDataWithPool = {
  data: {
    subscriptionUsage: {
      enabled: true,

      lastEventTransactionAt: '2025-02-02T18:45:32Z',

      subscriptionPortalUsageDashboardUrl: '/subscriptions/A-S042/usage',
      purchaseCreditsPath: '/purchase-credits-path',

      startDate: '2025-08-01',
      endDate: '2025-08-31',

      paidTierTrial: {
        isActive: false,
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
                monthlyCommitmentCreditsUsed: 500,
                monthlyWaiverCreditsUsed: 212,
                overageCreditsUsed: 100,
              },

              events: {
                nodes: [
                  {
                    timestamp: '2025-01-21T16:42:38Z',
                    flowType: 'Software Development Flow',
                    eventType: 'Software Development Flow',
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
                    flowType: 'Convert to GitLab CI/CD Flow',
                    eventType: 'Convert to GitLab CI/CD Flow',
                    location: {
                      __typename: 'Group',
                      id: '2',
                      name: 'group-app',
                      webUrl: 'http://localhost:3000/group-app',
                    },
                    creditsUsed: 6.24,
                  },
                  {
                    timestamp: '2025-01-21T16:40:22Z',
                    flowType: 'Agentic Chat',
                    eventType: 'Agentic Chat',
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
                    flowType: 'Code Review Flow',
                    eventType: 'Code Review Flow',
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
                    flowType: 'Fix Pipeline Flow',
                    eventType: 'Fix Pipeline Flow',
                    location: {
                      __typename: 'Project',
                      id: '1',
                      name: 'frontend-app',
                      webUrl: 'http://localhost:3000/frontend-app',
                    },
                    creditsUsed: 82.33333,
                  },
                  {
                    timestamp: '2025-01-21T16:37:33Z',
                    flowType: 'SAST Vulnerability Resolution Flow',
                    eventType: 'SAST Vulnerability Resolution Flow',
                    location: null,
                    creditsUsed: 55,
                  },
                  {
                    timestamp: '2025-01-21T16:36:58Z',
                    flowType: 'SAST FP Detection Flow',
                    eventType: 'SAST FP Detection Flow',
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
                    flowType: 'AI Catalog based Agent or Flow',
                    eventType: 'AI Catalog based Agent or Flow',
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
                    flowType: 'Developer Flow',
                    eventType: 'Developer Flow',
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
                    flowType: 'Other AI Usage',
                    eventType: 'Other AI Usage',
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
                    flowType: 'Other AI Usage',
                    eventType: 'Other AI Usage',
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

export const mockDataWithoutPool = merge({}, mockDataWithPool, {
  data: {
    subscriptionUsage: {
      monthlyCommitment: {
        creditsUsed: 0,
        totalCredits: 0,
      },

      usersUsage: {
        users: {
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
});

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

export const mockPaidTierTrialData = merge({}, mockEmptyData, {
  data: {
    subscriptionUsage: {
      paidTierTrial: {
        isActive: true,
      },
    },
  },
});

export const mockNullData = merge({}, mockEmptyData, {
  data: {
    subscriptionUsage: {
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
});

export const mockDisabledStateData = {
  data: {
    subscriptionUsage: {
      ...mockDataWithPool.data.subscriptionUsage,
      enabled: false,
    },
  },
};
