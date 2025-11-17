export const mockUsersUsageDataWithoutPool = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2024-01-15T10:30:00Z',
      purchaseCreditsPath: '/purchase-credits-path',
      usersUsage: {
        // overall statistics
        totalUsers: 50,
        totalUsersUsingAllocation: 35,
        totalUsersUsingMonthlyCommitment: null, // or 0
        totalUsersBlocked: 10,
        avgCreditsPerUser: 150,

        // per-user details
        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/1',
              name: 'Alice Johnson',
              username: 'ajohnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
              usage: {
                creditsUsed: 450,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
              },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 67,
              },
            },
            {
              id: 'gid://gitlab/User/3',
              name: 'Carol Davis',
              username: 'cdavis',
              avatarUrl: 'https://www.gravatar.com/avatar/3?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 89,
              },
            },
            {
              id: 'gid://gitlab/User/4',
              name: 'David Wilson',
              username: 'dwilson',
              avatarUrl: 'https://www.gravatar.com/avatar/4?s=80&d=identicon',
              usage: {
                creditsUsed: 320,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 42,
              },
            },
            {
              id: 'gid://gitlab/User/5',
              name: 'Eva Martinez',
              username: 'emartinez',
              avatarUrl: 'https://www.gravatar.com/avatar/5?s=80&d=identicon',
              usage: {
                creditsUsed: 100,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
              },
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};

// per user summaries for the month
export const mockUsersUsageDataWithPool = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      purchaseCreditsPath: '/purchase-credits-path',
      usersUsage: {
        // overall statistics
        totalUsers: 50,
        totalUsersUsingAllocation: 35,
        totalUsersUsingMonthlyCommitment: 15,
        totalUsersBlocked: 10,

        // per-user details
        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/1',
              name: 'Alice Johnson',
              username: 'ajohnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 70,
                monthlyWaiverCreditsUsed: 70,
                overageCreditsUsed: 50.333,
              },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
              },
            },
            {
              id: 'gid://gitlab/User/3',
              name: 'Carol Davis',
              username: 'cdavis',
              avatarUrl: 'https://www.gravatar.com/avatar/3?s=80&d=identicon',
              usage: {
                creditsUsed: 50,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
              },
            },
            {
              id: 'gid://gitlab/User/4',
              name: 'David Wilson',
              username: 'dwilson',
              avatarUrl: 'https://www.gravatar.com/avatar/4?s=80&d=identicon',
              usage: {
                creditsUsed: 2000,
                totalCredits: 2000,
                monthlyCommitmentCreditsUsed: 100,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 42.111,
              },
            },
            {
              id: 'gid://gitlab/User/5',
              name: 'Eva Martinez',
              username: 'emartinez',
              avatarUrl: 'https://www.gravatar.com/avatar/5?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 75.888,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 15,
              },
            },
            {
              id: 'gid://gitlab/User/6',
              name: 'Frank Thompson',
              username: 'fthompson',
              avatarUrl: 'https://www.gravatar.com/avatar/6?s=80&d=identicon',
              usage: {
                creditsUsed: 480,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 56,
              },
            },
            {
              id: 'gid://gitlab/User/7',
              name: 'Grace Lee',
              username: 'glee',
              avatarUrl: 'https://www.gravatar.com/avatar/7?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 150,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 91,
              },
            },
            {
              id: 'gid://gitlab/User/8',
              name: 'Henry Brown',
              username: 'hbrown',
              avatarUrl: 'https://www.gravatar.com/avatar/8?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 300,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 34,
              },
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};

export const mockUsersUsageDataWithOverage = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      purchaseCreditsPath: '/purchase-credits-path',
      usersUsage: {
        totalUsers: 50,
        totalUsersUsingAllocation: 35,
        totalUsersUsingMonthlyCommitment: 15,
        totalUsersBlocked: 10,

        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/1',
              name: 'Alice Johnson',
              username: 'ajohnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
              usage: {
                creditsUsed: 450,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 23,
              },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 125,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 67,
              },
            },
            {
              id: 'gid://gitlab/User/3',
              name: 'Carol Davis',
              username: 'cdavis',
              avatarUrl: 'https://www.gravatar.com/avatar/3?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 200,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 89,
              },
            },
            {
              id: 'gid://gitlab/User/4',
              name: 'David Wilson',
              username: 'dwilson',
              avatarUrl: 'https://www.gravatar.com/avatar/4?s=80&d=identicon',
              usage: {
                creditsUsed: 320,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 42,
              },
            },
            {
              id: 'gid://gitlab/User/5',
              name: 'Eva Martinez',
              username: 'emartinez',
              avatarUrl: 'https://www.gravatar.com/avatar/5?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 75,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 15,
              },
            },
            {
              id: 'gid://gitlab/User/6',
              name: 'Frank Thompson',
              username: 'fthompson',
              avatarUrl: 'https://www.gravatar.com/avatar/6?s=80&d=identicon',
              usage: {
                creditsUsed: 480,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 56,
              },
            },
            {
              id: 'gid://gitlab/User/7',
              name: 'Grace Lee',
              username: 'glee',
              avatarUrl: 'https://www.gravatar.com/avatar/7?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 150,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 91,
              },
            },
            {
              id: 'gid://gitlab/User/8',
              name: 'Henry Brown',
              username: 'hbrown',
              avatarUrl: 'https://www.gravatar.com/avatar/8?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 300,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 34,
              },
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};

export const mockUsersUsageDataWithZeroAllocation = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      purchaseCreditsPath: '/purchase-credits-path',
      startDate: '2025-10-01',
      endDate: '2025-10-31',

      usersUsage: {
        totalUsers: 5,
        totalUsersUsingAllocation: 2,
        totalUsersUsingMonthlyCommitment: 0,
        totalUsersBlocked: 1,

        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/1',
              name: 'Alice Johnson',
              username: 'ajohnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
              usage: {
                creditsUsed: 0,
                totalCredits: 0,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 12,
                overageCreditsUsed: 15,
              },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                creditsUsed: 0,
                totalCredits: 0,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
              },
            },
            {
              id: 'gid://gitlab/User/3',
              name: 'Carol Davis',
              username: 'cdavis',
              avatarUrl: 'https://www.gravatar.com/avatar/3?s=80&d=identicon',
              usage: {
                creditsUsed: 0,
                totalCredits: 0,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 5,
                overageCreditsUsed: 89,
              },
            },
            {
              id: 'gid://gitlab/User/4',
              name: 'David Wilson',
              username: 'dwilson',
              avatarUrl: 'https://www.gravatar.com/avatar/4?s=80&d=identicon',
              usage: {
                creditsUsed: 0,
                totalCredits: 0,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 42,
              },
            },
            {
              id: 'gid://gitlab/User/5',
              name: 'Eva Martinez',
              username: 'emartinez',
              avatarUrl: 'https://www.gravatar.com/avatar/5?s=80&d=identicon',
              usage: {
                creditsUsed: 0,
                totalCredits: 0,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
              },
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};

export const mockUsersUsageDataWithNullUsage = {
  data: {
    subscriptionUsage: {
      usersUsage: {
        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/6120463',
              name: 'Bryan Rothwell',
              username: 'brothwell',
              avatarUrl:
                'https://secure.gravatar.com/avatar/17c92ab7acbe41a4fd2e243828e5b711b3475526b188aa96c0f5039392d64ad8?s=80&d=identicon',
              usage: {
                creditsUsed: null,
                totalCredits: 24,
                monthlyCommitmentCreditsUsed: null,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: null,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/5487870',
              name: 'Jorge Cook',
              username: 'jecook',
              avatarUrl:
                'https://secure.gravatar.com/avatar/4da03f30b1328ab1bf4ce9cfe88f447af5ad030bc52ef5825ab6bf06301bf39c?s=80&d=identicon',
              usage: {
                creditsUsed: null,
                totalCredits: 24,
                monthlyCommitmentCreditsUsed: null,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: null,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1943919',
              name: 'Kos Palchyk',
              username: 'kpalchyk',
              avatarUrl:
                'https://secure.gravatar.com/avatar/be1b9a030c184bc489faaa8fbb6679874660bbcec5df62bcd8dbd11cec02a4eb?s=80&d=identicon',
              usage: {
                creditsUsed: null,
                totalCredits: null,
                monthlyCommitmentCreditsUsed: null,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: null,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1862366',
              name: 'Sharmad Nachnolkar',
              username: 'snachnolkar',
              avatarUrl:
                'https://secure.gravatar.com/avatar/57e70f889048d230e2c7945babbe8bec8cbc90e20cf7b0388cd801a52f2243c6?s=80&d=identicon',
              usage: {
                creditsUsed: null,
                totalCredits: 24,
                monthlyCommitmentCreditsUsed: null,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: null,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1860447',
              name: 'Suraj Mahendra Tripathi',
              username: 'suraj_tripathy',
              avatarUrl:
                'https://secure.gravatar.com/avatar/97615be7789c22621ed96bc730c6819933fef80b1a7af3f95910c17f0e8615d3?s=80&d=identicon',
              usage: {
                creditsUsed: null,
                totalCredits: 24,
                monthlyCommitmentCreditsUsed: null,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: null,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1790300',
              name: 'Courtney Meddaugh',
              username: 'cmeddaugh',
              avatarUrl:
                'https://secure.gravatar.com/avatar/b4f1716310d4bb11d742604f8dda7ec30cebf0e7eacdbc241d42eb155c54fb03?s=80&d=identicon',
              usage: {
                creditsUsed: null,
                totalCredits: 24,
                monthlyCommitmentCreditsUsed: null,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: null,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1759714',
              name: 'Sheldon Led',
              username: 'sheldonled',
              avatarUrl:
                'https://secure.gravatar.com/avatar/d72fd8312645f293d485dfb87a50828c261e535357b6fe4bf4886332db33cd1a?s=80&d=identicon',
              usage: {
                creditsUsed: null,
                totalCredits: 24,
                monthlyCommitmentCreditsUsed: null,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: null,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1676960',
              name: 'Vijay Hawoldar',
              username: 'vhawoldar',
              avatarUrl:
                'https://secure.gravatar.com/avatar/e1fff3213210ed09a02bd837eb857a893683abb4cc5640a79929455c88a71487?s=80&d=identicon',
              usage: {
                creditsUsed: 0,
                totalCredits: 24,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: 0,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1675936',
              name: 'Ammar Alakkad',
              username: 'aalakkad',
              avatarUrl:
                'https://secure.gravatar.com/avatar/ef6157f79905c001112efda96ceb98fa1b0524a40ee9148bcf410793333a2614?s=80&d=identicon',
              usage: {
                creditsUsed: null,
                totalCredits: 24,
                monthlyCommitmentCreditsUsed: null,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: null,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1675825',
              name: 'Tyler Amos',
              username: 'tyleramos',
              avatarUrl:
                'https://secure.gravatar.com/avatar/6156236af081924c152da7bfc5b2ce1110628e2bb7a17ca2239038ec5a4f57bb?s=80&d=identicon',
              usage: {
                creditsUsed: null,
                totalCredits: 24,
                monthlyCommitmentCreditsUsed: null,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: null,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              __typename: 'GitlabSubscriptionUsageUser',
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: 'eyJpZCI6IjYxMjA0NjMifQ',
            endCursor: 'eyJpZCI6IjE2NzU4MjUifQ',
            __typename: 'PageInfo',
          },
          __typename: 'GitlabSubscriptionUsageUserConnection',
        },
        __typename: 'GitlabSubscriptionUsageUsersUsage',
      },
      __typename: 'GitlabSubscriptionUsage',
    },
  },
};

export const usageDataWithCommitment = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',
      monthlyCommitment: {
        creditsUsed: 50.333,
        totalCredits: 100,
        dailyUsage: [
          { creditsUsed: 5, date: '2025-10-06' },
          { creditsUsed: 12, date: '2025-10-07' },
          { creditsUsed: 18, date: '2025-10-10' },
          { creditsUsed: 15.333, date: '2025-10-11' },
        ],
      },
      overage: {
        isAllowed: true,
        creditsUsed: 0,
        dailyUsage: [],
      },

      monthlyWaiver: {
        totalCredits: 0,
        creditsUsed: 0,
        dailyUsage: [],
      },
    },
  },
};

export const usageDataWithoutLastEventTransactionAt = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: null,
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',

      monthlyCommitment: null,
      monthlyWaiver: null,
      overage: null,
    },
  },
};

export const usageDataWithCommitmentWithMonthlyWaiver = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',

      monthlyCommitment: {
        creditsUsed: 50,
        totalCredits: 50,
        dailyUsage: [
          { creditsUsed: 5, date: '2025-10-06' },
          { creditsUsed: 12, date: '2025-10-07' },
          { creditsUsed: 18, date: '2025-10-10' },
          { creditsUsed: 15, date: '2025-10-11' },
        ],
      },
      monthlyWaiver: {
        creditsUsed: 50.125,
        totalCredits: 100,
        dailyUsage: [
          { creditsUsed: 8.5, date: '2025-10-12' },
          { creditsUsed: 12.25, date: '2025-10-13' },
          { creditsUsed: 15.375, date: '2025-10-14' },
          { creditsUsed: 14, date: '2025-10-15' },
        ],
      },
      overage: {
        isAllowed: false,
        creditsUsed: 0,
        dailyUsage: [],
      },
    },
  },
};

export const usageDataWithCommitmentWithOverage = {
  data: {
    subscriptionUsage: {
      purchaseCreditsPath: '/purchase-credits-path',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      monthlyCommitment: {
        creditsUsed: 50,
        totalCredits: 50,
        dailyUsage: [
          { creditsUsed: 5, date: '2025-10-06' },
          { creditsUsed: 12, date: '2025-10-07' },
          { creditsUsed: 18, date: '2025-10-10' },
          { creditsUsed: 15, date: '2025-10-11' },
        ],
      },
      overage: {
        isAllowed: true,
        creditsUsed: 50,
        dailyUsage: [
          { creditsUsed: 8.5, date: '2025-10-15' },
          { creditsUsed: 12.25, date: '2025-10-16' },
          { creditsUsed: 15.75, date: '2025-10-17' },
          { creditsUsed: 13.5, date: '2025-10-18' },
        ],
      },

      monthlyWaiver: {
        totalCredits: 0,
        creditsUsed: 0,
        dailyUsage: [],
      },
    },
  },
};

export const usageDataNoCommitmentNoMonthlyWaiverNoOverage = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2024-01-15T10:30:00Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',
      monthlyCommitment: null,
      overage: {
        isAllowed: false,
        creditsUsed: 0,
        dailyUsage: [],
      },

      monthlyWaiver: {
        totalCredits: 0,
        creditsUsed: 0,
        dailyUsage: [],
      },
    },
  },
};

export const usageDataNoCommitmentWithOverage = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2024-01-15T10:30:00Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',
      monthlyCommitment: null,
      overage: {
        isAllowed: true,
        creditsUsed: 50,
        dailyUsage: [
          { creditsUsed: 10.5, date: '2025-10-01' },
          { creditsUsed: 8.75, date: '2025-10-02' },
          { creditsUsed: 12.25, date: '2025-10-03' },
          { creditsUsed: 9.5, date: '2025-10-04' },
          { creditsUsed: 9, date: '2025-10-05' },
        ],
      },

      monthlyWaiver: {
        totalCredits: 0,
        creditsUsed: 0,
        dailyUsage: [],
      },
    },
  },
};

export const usageDataCommitmentWithMonthlyWaiver = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',

      monthlyCommitment: {
        creditsUsed: 50,
        totalCredits: 50,
        dailyUsage: [
          { creditsUsed: 8, date: '2025-10-01' },
          { creditsUsed: 12, date: '2025-10-02' },
          { creditsUsed: 10, date: '2025-10-03' },
          { creditsUsed: 15, date: '2025-10-04' },
          { creditsUsed: 5, date: '2025-10-05' },
        ],
      },

      overage: {
        isAllowed: true,
        creditsUsed: 0,
        dailyUsage: [],
      },

      monthlyWaiver: {
        totalCredits: 100,
        creditsUsed: 75,
        dailyUsage: [
          { creditsUsed: 12.5, date: '2025-10-06' },
          { creditsUsed: 15.25, date: '2025-10-07' },
          { creditsUsed: 18.75, date: '2025-10-08' },
          { creditsUsed: 14.5, date: '2025-10-09' },
          { creditsUsed: 14, date: '2025-10-10' },
        ],
      },
    },
  },
};

export const usageDataCommitmentWithMonthlyWaiverWithOverage = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',

      monthlyCommitment: {
        creditsUsed: 100,
        totalCredits: 100,
        dailyUsage: [
          { creditsUsed: 18, date: '2025-10-01' },
          { creditsUsed: 22, date: '2025-10-02' },
          { creditsUsed: 20, date: '2025-10-03' },
          { creditsUsed: 25, date: '2025-10-04' },
          { creditsUsed: 15, date: '2025-10-05' },
        ],
      },

      overage: {
        isAllowed: true,
        creditsUsed: 24,
        dailyUsage: [
          { creditsUsed: 4.5, date: '2025-10-11' },
          { creditsUsed: 6.25, date: '2025-10-12' },
          { creditsUsed: 7.75, date: '2025-10-13' },
          { creditsUsed: 5.5, date: '2025-10-14' },
        ],
      },

      monthlyWaiver: {
        totalCredits: 100,
        creditsUsed: 100,
        dailyUsage: [
          { creditsUsed: 16.5, date: '2025-10-06' },
          { creditsUsed: 22.25, date: '2025-10-07' },
          { creditsUsed: 28.125, date: '2025-10-08' },
          { creditsUsed: 21.125, date: '2025-10-09' },
          { creditsUsed: 12, date: '2025-10-10' },
        ],
      },
    },
  },
};

export const usageDataWithOutdatedClient = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: true,
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',
      monthlyCommitment: null,
      monthlyWaiver: null,
      overage: null,
    },
  },
};

export const usageDataWithDisabledState = {
  data: {
    subscriptionUsage: {
      enabled: false,
      isOutdatedClient: null,
      lastEventTransactionAt: null,
      startDate: null,
      endDate: null,
      purchaseCreditsPath: null,
      monthlyCommitment: null,
      monthlyWaiver: null,
      overage: null,
    },
  },
};

export const usageDataWithoutPurchaseCreditsPath = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: null,
      monthlyCommitment: null,
      monthlyWaiver: null,
      overage: null,
    },
  },
};
