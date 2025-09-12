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

        totalUnitsUsed: 500,
        firstConsumptionDate: '2025-01-01',
        allocationUsed: 500,
        allocationTotal: 8452,
        poolUsed: 5140,
        events: [
          {
            timestamp: '2025-01-21T16:42:38Z',
            eventType: 'Duo Workflow - Code Generation',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            gitlabUnits: 44,
            status: 'Normal usage',
          },
          {
            timestamp: '2025-01-21T16:41:15Z',
            eventType: 'Duo Chat - Extended Session',
            location: {
              name: 'group-app',
              web_url: 'http://localhost:3000/group-app',
            },
            gitlabUnits: 62,
            status: 'Normal usage',
          },
          {
            timestamp: '2025-01-21T16:40:22Z',
            eventType: 'Code Suggestions - Completion',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            gitlabUnits: 30,
            status: 'Normal usage',
          },
          {
            timestamp: '2025-01-21T16:39:45Z',
            eventType: 'Duo Workflow - Test Generation',
            location: {
              name: 'group-app',
              web_url: 'http://localhost:3000/group-app',
            },
            gitlabUnits: 45,
            status: 'Normal usage',
          },
          {
            timestamp: '2025-01-21T16:38:12Z',
            eventType: 'Code Review Assistant',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            gitlabUnits: 82,
            status: 'Normal usage',
          },
          {
            timestamp: '2025-01-21T16:37:33Z',
            eventType: 'Duo Chat',
            location: null,
            gitlabUnits: 55,
            status: 'Normal usage',
          },
          {
            timestamp: '2025-01-21T16:36:58Z',
            eventType: 'Code Suggestions - Refactoring',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            gitlabUnits: 26,
            status: 'Normal usage',
          },
          {
            timestamp: '2025-01-21T16:35:41Z',
            eventType: 'Vulnerability Explanation',
            location: {
              name: 'group-app',
              web_url: 'http://localhost:3000/group-app',
            },
            gitlabUnits: 74,
            status: 'Normal usage',
          },
          {
            timestamp: '2025-01-21T16:34:27Z',
            eventType: 'Duo Workflow - Code Generation',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            gitlabUnits: 51,
            status: 'Normal usage',
          },
          {
            timestamp: '2025-01-21T16:33:05Z',
            eventType: 'Duo Workflow - Code Generation',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            gitlabUnits: 70,
            status: 'Normal usage',
          },
          {
            timestamp: '2025-01-21T16:31:52Z',
            eventType: 'Duo Workflow - Code Generation',
            location: {
              name: 'frontend-app',
              web_url: 'http://localhost:3000/frontend-app',
            },
            gitlabUnits: 15,
            status: 'Normal usage',
          },
        ],
      },
    },
  },
};
