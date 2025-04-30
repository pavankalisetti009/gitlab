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
            avatarUrl: '/avatar.png',
            webUrl: 'http://gdk.test:3000/groups/flightjs/test-subgroup',
            vulnerabilityNamespaceStatistic: {
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
            vulnerabilityStatistic: {
              critical: 10,
              high: 5,
              low: 4,
              info: 0,
              medium: 48,
              unknown: 7,
            },
            securityScanners: {
              enabled: ['SAST', 'SAST_ADVANCED'],
              pipelineRun: ['SAST'],
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
            vulnerabilityStatistic: {
              critical: 10,
              high: 0,
              low: 0,
              info: 0,
              medium: 0,
              unknown: 0,
            },
            securityScanners: {
              enabled: ['SAST', 'SAST_ADVANCED'],
              pipelineRun: [],
            },
          },
        ],
      },
    },
  },
};

export const groupWithSubgroups = {
  data: {
    group: {
      id: 'gid://gitlab/Group/3',
      name: 'A group',
      fullPath: 'a-group',
      avatarUrl: 'a_group_avatar.png',
      descendantGroups: {
        nodes: [
          {
            __typename: 'Group',
            id: 'gid://gitlab/Group/31',
            name: 'Subgroup with projects and subgroups',
            projectsCount: 3,
            descendantGroupsCount: 2,
            fullPath: 'a-group/subgroup-with-projects-and-subgroups',
          },
          {
            __typename: 'Group',
            id: 'gid://gitlab/Group/32',
            name: 'Subgroup with projects',
            projectsCount: 2,
            descendantGroupsCount: 0,
            fullPath: 'a-group/subgroup-with-projects',
          },
          {
            __typename: 'Group',
            id: 'gid://gitlab/Group/33',
            name: 'Subgroup with subgroups',
            projectsCount: 0,
            descendantGroupsCount: 3,
            fullPath: 'a-group/subgroup-with-subgroups',
          },
          {
            __typename: 'Group',
            id: 'gid://gitlab/Group/34',
            name: 'Empty subgroup',
            projectsCount: 0,
            descendantGroupsCount: 0,
            fullPath: 'a-group/empty-subgroup',
          },
        ],
        pageInfo: {
          hasNextPage: true,
          endCursor: 'END_CURSOR',
        },
      },
    },
  },
};
