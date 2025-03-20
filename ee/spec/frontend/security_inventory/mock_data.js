export const subgroupsAndProjects = {
  data: {
    group: {
      id: 'gid://gitlab/Group/33',
      projectsCount: 2,
      descendantGroupsCount: 1,
      avatarUrl: null,
      descendantGroups: {
        nodes: [
          {
            __typename: 'Group',
            id: 'gid://gitlab/Group/211',
            name: 'Test Subgroup',
            descendantGroupsCount: 0,
            projectsCount: 1,
            path: 'test-subgroup',
            fullPath: 'flightjs/test-subgroup',
            avatarUrl: null,
            webUrl: 'http://gdk.test:3000/groups/flightjs/test-subgroup',
            vulnerabilitySeveritiesCount: {
              critical: 10,
              high: 10,
              low: 10,
              info: 10,
              medium: 20,
              unknown: 20,
            },
          },
        ],
      },
      projects: {
        nodes: [
          {
            __typename: 'Project',
            id: 'gid://gitlab/Project/19',
            name: 'security-reports-example',
            path: 'security-reports-example',
            fullPath: 'flightjs/security-reports-example',
            avatarUrl: null,
            webUrl: 'http://gdk.test:3000/flightjs/security-reports-example',
            vulnerabilitySeveritiesCount: {
              critical: 10,
              high: 5,
              low: 4,
              info: 0,
              medium: 48,
              unknown: 7,
            },
          },
          {
            __typename: 'Project',
            id: 'gid://gitlab/Project/7',
            name: 'Flight',
            path: 'Flight',
            fullPath: 'flightjs/Flight',
            avatarUrl: null,
            webUrl: 'http://gdk.test:3000/flightjs/Flight',
            vulnerabilitySeveritiesCount: {
              critical: 10,
              high: 0,
              low: 0,
              info: 0,
              medium: 0,
              unknown: 0,
            },
          },
        ],
      },
    },
  },
};
