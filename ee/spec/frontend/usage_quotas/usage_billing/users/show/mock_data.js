export const mockData = {
  subscription: {
    gitlabUnitsUsage: {
      lastUpdated: '2025-02-02T18:45:32Z',

      startDate: '2025-08-01',
      endDate: '2025-08-31',

      userUsage: {
        user: {
          id: 42,
          username: 'alice_johnson',
          name: 'Alice Johnson',
          avatar_url: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
        },

        totalUnitsUsed: 1500,
        firstConsumptionDate: '2025-01-01',
        allocationUsed: 1000,
        allocationTotal: 1000,
        poolUsed: 500,

        events: [
          {
            timestamp: '2025-01-21T16:42:38Z',
            eventType: 'Duo Workflow - Code Generation',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            unitsUsed: 44,
          },
          {
            timestamp: '2025-01-21T16:41:15Z',
            eventType: 'Duo Chat - Extended Session',
            location: {
              name: 'group-app',
              web_url: 'http://localhost:3000/group-app',
            },
            unitsUsed: 62,
          },
          {
            timestamp: '2025-01-21T16:40:22Z',
            eventType: 'Code Suggestions - Completion',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            unitsUsed: 30,
          },
          {
            timestamp: '2025-01-21T16:39:45Z',
            eventType: 'Duo Workflow - Test Generation',
            location: {
              name: 'group-app',
              web_url: 'http://localhost:3000/group-app',
            },
            unitsUsed: 45,
          },
          {
            timestamp: '2025-01-21T16:38:12Z',
            eventType: 'Code Review Assistant',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            unitsUsed: 82,
          },
          {
            timestamp: '2025-01-21T16:37:33Z',
            eventType: 'Duo Chat',
            location: null,
            unitsUsed: 55,
          },
          {
            timestamp: '2025-01-21T16:36:58Z',
            eventType: 'Code Suggestions - Refactoring',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            unitsUsed: 26,
          },
          {
            timestamp: '2025-01-21T16:35:41Z',
            eventType: 'Vulnerability Explanation',
            location: {
              name: 'group-app',
              web_url: 'http://localhost:3000/group-app',
            },
            unitsUsed: 74,
          },
          {
            timestamp: '2025-01-21T16:34:27Z',
            eventType: 'Duo Workflow - Code Generation',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            unitsUsed: 51,
          },
          {
            timestamp: '2025-01-21T16:33:05Z',
            eventType: 'Duo Workflow - Code Generation',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            unitsUsed: 70,
          },
          {
            timestamp: '2025-01-21T16:31:52Z',
            eventType: 'Duo Workflow - Code Generation',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            unitsUsed: 15,
          },
        ],
      },
    },
  },
};

export const mockEmptyData = {
  subscription: {
    gitlabUnitsUsage: {
      lastUpdated: '2025-02-02T18:45:32Z',

      startDate: '2025-08-01',
      endDate: '2025-08-31',

      userUsage: {
        user: {
          id: 42,
          username: 'alice_johnson',
          name: 'Alice Johnson',
          avatar_url: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
        },

        totalUnitsUsed: 0,
        firstConsumptionDate: '2025-01-01',
        allocationUsed: 0,
        allocationTotal: 10000,
        poolUsed: 0,

        events: [],
      },
    },
  },
};
