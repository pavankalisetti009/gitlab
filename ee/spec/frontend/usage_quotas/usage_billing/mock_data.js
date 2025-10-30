export const mockUsersUsageDataWithoutPool = {
  data: {
    subscriptionUsage: {
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
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 0,
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
                creditsUsed: 450,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 125,
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
                monthlyCommitmentCreditsUsed: 200,
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
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 75,
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
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 150,
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
                monthlyCommitmentCreditsUsed: 300,
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

export const mockUsersUsageDataWithOverage = {
  data: {
    subscriptionUsage: {
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
                monthlyCommitmentCreditsUsed: 125,
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
                monthlyCommitmentCreditsUsed: 200,
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
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 75,
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
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 150,
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
                monthlyCommitmentCreditsUsed: 300,
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

export const mockUsersUsageDataWithZeroAllocation = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      purchaseCreditsPath: '/purchase-credits-path',
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
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 0,
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
                monthlyCommitmentCreditsUsed: 0,
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

export const usageDataWithCommitment = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',
      monthlyCommitment: {
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
      monthlyCommitment: {
        creditsUsed: 50,
        totalCredits: 300,
      },
    },
  },
};

export const usageDataWithCommitmentWithOtc = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',

      monthlyCommitment: {
        creditsUsed: 300,
        totalCredits: 300,
      },
      oneTimeCredits: {
        totalCreditsRemaining: 0,
        creditsUsed: 200,
      },
      overage: {
        isAllowed: false,
        creditsUsed: 0,
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
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      monthlyCommitment: {
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

export const usageDataNoCommitmentNoOtcNoOverage = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2024-01-15T10:30:00Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',
      monthlyCommitment: null,
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

export const usageDataNoCommitmentWithOverage = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2024-01-15T10:30:00Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',
      monthlyCommitment: null,
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

export const usageDataCommitmentWithOtc = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',

      monthlyCommitment: {
        creditsUsed: 50,
        totalCredits: 300,
      },

      overage: {
        isAllowed: true,
        creditsUsed: 0,
      },

      oneTimeCredits: {
        totalCreditsRemaining: 250,
        creditsUsed: 750,
      },
    },
  },
};

export const usageDataCommitmentWithOtcWithOverage = {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T07:41:59Z',
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      purchaseCreditsPath: '/purchase-credits-path',

      monthlyCommitment: {
        creditsUsed: 50,
        totalCredits: 300,
      },

      overage: {
        isAllowed: true,
        creditsUsed: 100,
      },

      oneTimeCredits: {
        totalCreditsRemaining: 0,
        creditsUsed: 1000,
      },
    },
  },
};
