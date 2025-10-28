export const mockUsageDataWithoutPool = {
  subscription: {
    gitlabCreditsUsage: {
      // boundaries
      startDate: '2024-01-01',
      endDate: '2024-01-31',

      overageCredits: 0,
      totalCredits: 0,
      totalCreditsUsed: 0,

      overage: {
        isAllowed: false,
        creditsUsed: 0,
      },

      oneTimeCredits: {
        totalCreditsRemaining: 0,
        creditsUsed: 0,
      },

      // pool allocation statistics (commitment)
      poolUsage: null,

      // daily seat allocation usage statistics
      seatUsage: {
        dailyAverage: 167,
        peakUsage: 234,
        usageTrend: 0.12,
        // daily summaries for the month
        dailyUsage: [
          ['2025-07-15', 7076],
          ['2025-07-16', 7235],
          ['2025-07-17', 6789],
          ['2025-07-18', 6855],
          ['2025-07-19', 6482],
          ['2025-07-20', 6887],
          ['2025-07-21', 6662],
          ['2025-07-22', 6124],
          ['2025-07-23', 6433],
          ['2025-07-24', 7028],
          ['2025-07-25', 7103],
          ['2025-07-26', 7307],
          ['2025-07-27', 7618],
          ['2025-07-28', 8326],
          ['2025-07-29', 8549],
          ['2025-07-30', 9208],
          ['2025-07-31', 10008],
          ['2025-08-01', 9566],
          ['2025-08-02', 9909],
          ['2025-08-03', 10706],
          ['2025-08-04', 10056],
          ['2025-08-05', 10253],
          ['2025-08-06', 10213],
          ['2025-08-07', 10494],
          ['2025-08-08', 10040],
          ['2025-08-09', 10338],
          ['2025-08-10', 9168],
          ['2025-08-11', 9610],
          ['2025-08-12', 9125],
          ['2025-08-13', 8178],
        ],
      },
    },
  },
};

export const mockUsersUsageDataWithoutPool = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2024-01-15T10:30:00Z',
      purchaseCreditsPath: '/purchase-credits-path',
      usersUsage: {
        // overall statistics
        totalUsers: 50,
        totalUsersUsingAllocation: 35,
        totalUsersUsingPool: null, // or 0
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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

// Mock data for daily usage API response
export const mockUsageDataWithPool = {
  subscription: {
    gitlabCreditsUsage: {
      // boundaries
      startDate: '2024-01-01',
      endDate: '2024-01-31',

      overageCredits: 0,
      totalCredits: 300,
      totalCreditsUsed: 50,

      overage: {
        isAllowed: true,
        creditsUsed: 0,
      },

      oneTimeCredits: {
        totalCreditsRemaining: 0,
        creditsUsed: 0,
      },

      // pool allocation statistics (commitment)
      poolUsage: {
        // statistics
        dailyAverage: 167,
        peakUsage: 234,
        usageTrend: 0.12,
        // daily summaries for the month
        dailyUsage: [
          ['2025-07-15', 7076],
          ['2025-07-16', 7235],
          ['2025-07-17', 6789],
          ['2025-07-18', 6855],
          ['2025-07-19', 6482],
          ['2025-07-20', 6887],
          ['2025-07-21', 6662],
          ['2025-07-22', 6124],
          ['2025-07-23', 6433],
          ['2025-07-24', 7028],
          ['2025-07-25', 7103],
          ['2025-07-26', 7307],
          ['2025-07-27', 7618],
          ['2025-07-28', 8326],
          ['2025-07-29', 8549],
          ['2025-07-30', 9208],
          ['2025-07-31', 10008],
          ['2025-08-01', 9566],
          ['2025-08-02', 9909],
          ['2025-08-03', 10706],
          ['2025-08-04', 10056],
          ['2025-08-05', 10253],
          ['2025-08-06', 10213],
          ['2025-08-07', 10494],
          ['2025-08-08', 10040],
          ['2025-08-09', 10338],
          ['2025-08-10', 9168],
          ['2025-08-11', 9610],
          ['2025-08-12', 9125],
          ['2025-08-13', 8178],
        ],
      },

      // daily seat allocation usage statistics
      // we probably can skip seat usage data
      seatUsage: null,
    },
  },
};

// per user summaries for the month
export const mockUsersUsageDataWithPool = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      purchaseCreditsPath: '/purchase-credits-path',
      usersUsage: {
        // overall statistics
        totalUsers: 50,
        totalUsersUsingAllocation: 35,
        totalUsersUsingPool: 15,
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
                creditsUsed: 450,
                totalCredits: 500,
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 125,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 200,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 75,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 150,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 300,
                oneTimeCreditsUsed: 0,
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

export const mockUsageDataWithOverage = {
  subscription: {
    gitlabCreditsUsage: {
      startDate: '2024-01-01',
      endDate: '2024-01-31',

      overageCredits: 50,
      totalCredits: 300,
      totalCreditsUsed: 350,

      overage: {
        isAllowed: true,
        creditsUsed: 50,
      },

      oneTimeCredits: {
        totalCreditsRemaining: 0,
        creditsUsed: 0,
      },

      poolUsage: {
        dailyAverage: 167,
        peakUsage: 234,
        usageTrend: 0.12,
        dailyUsage: [
          ['2025-07-15', 7076],
          ['2025-07-16', 7235],
          ['2025-07-17', 6789],
          ['2025-07-18', 6855],
          ['2025-07-19', 6482],
          ['2025-07-20', 6887],
          ['2025-07-21', 6662],
          ['2025-07-22', 6124],
          ['2025-07-23', 6433],
          ['2025-07-24', 7028],
          ['2025-07-25', 7103],
          ['2025-07-26', 7307],
          ['2025-07-27', 7618],
          ['2025-07-28', 8326],
          ['2025-07-29', 8549],
          ['2025-07-30', 9208],
          ['2025-07-31', 10008],
          ['2025-08-01', 9566],
          ['2025-08-02', 9909],
          ['2025-08-03', 10706],
          ['2025-08-04', 10056],
          ['2025-08-05', 10253],
          ['2025-08-06', 10213],
          ['2025-08-07', 10494],
          ['2025-08-08', 10040],
          ['2025-08-09', 10338],
          ['2025-08-10', 9168],
          ['2025-08-11', 9610],
          ['2025-08-12', 9125],
          ['2025-08-13', 8178],
        ],
      },

      seatUsage: null,
    },
  },
};

export const mockUsersUsageDataWithOverage = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      purchaseCreditsPath: '/purchase-credits-path',
      usersUsage: {
        totalUsers: 50,
        totalUsersUsingAllocation: 35,
        totalUsersUsingPool: 15,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 125,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 200,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 75,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 150,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 300,
                oneTimeCreditsUsed: 0,
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

// Mock data with zero allocation totals for testing edge cases
export const mockUsageDataWithZeroAllocation = {
  subscription: {
    gitlabCreditsUsage: {
      startDate: '2024-01-01',
      endDate: '2024-01-31',

      overageCredits: 0,
      totalCredits: 100,
      totalCreditsUsed: 100,

      overage: {
        isAllowed: false,
        creditsUsed: 0,
      },

      poolUsage: null,
      seatUsage: null,
    },
  },
};

export const mockUsersUsageDataWithZeroAllocation = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      purchaseCreditsPath: '/purchase-credits-path',
      usersUsage: {
        totalUsers: 5,
        totalUsersUsingAllocation: 2,
        totalUsersUsingPool: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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
                poolCreditsUsed: 0,
                oneTimeCreditsUsed: 0,
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

export const usageDataWithPool = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      purchaseCreditsPath: '/purchase-credits-path',
      poolUsage: {
        creditsUsed: 50,
        totalCredits: 300,
      },
      overage: {
        isAllowed: true,
        creditsUsed: 0,
      },

      oneTimeCredits: {
        totalCreditsRemaining: 0,
        creditsUsed: 0,
      },
    },
  },
};

export const usageDataWithoutLastEventTransactionAt = {
  data: {
    subscriptionUsage: {
      poolUsage: {
        creditsUsed: 50,
        totalCredits: 300,
      },
    },
  },
};

export const usageDataWithPoolWithOverage = {
  data: {
    subscriptionUsage: {
      purchaseCreditsPath: '/purchase-credits-path',
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      poolUsage: {
        creditsUsed: 300,
        totalCredits: 300,
      },
      overage: {
        isAllowed: true,
        creditsUsed: 50,
      },

      oneTimeCredits: {
        totalCreditsRemaining: 0,
        creditsUsed: 0,
      },
    },
  },
};

export const usageDataNoPoolNoOverage = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2024-01-15T10:30:00Z',
      purchaseCreditsPath: '/purchase-credits-path',
      poolUsage: null,
      overage: {
        isAllowed: false,
        creditsUsed: 0,
      },

      oneTimeCredits: {
        totalCreditsRemaining: 0,
        creditsUsed: 0,
      },
    },
  },
};

export const usageDataNoPoolWithOverage = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2024-01-15T10:30:00Z',
      purchaseCreditsPath: '/purchase-credits-path',
      poolUsage: null,
      overage: {
        isAllowed: true,
        creditsUsed: 50,
      },

      oneTimeCredits: {
        totalCreditsRemaining: 0,
        creditsUsed: 0,
      },
    },
  },
};

export const usageDataWithOtcCredits = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      purchaseCreditsPath: '/purchase-credits-path',
      usersUsage: {
        // overall statistics
        totalUsers: 50,
        users: {
          nodes: [],
        },
      },
      poolUsage: {
        creditsUsed: 50,
        totalCredits: 300,
      },

      overage: {
        isAllowed: true,
        creditsUsed: 0,
      },

      oneTimeCredits: {
        totalCreditsRemaining: 500,
        creditsUsed: 2500,
      },
    },
  },
};
