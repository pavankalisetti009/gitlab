export const todosGroupsResponse = {
  data: {
    currentUser: {
      id: 'gid://gitlab/User/1',
      __typename: 'User',
      groups: {
        nodes: [
          {
            id: 'gid://gitlab/Group/1',
            name: 'My very first group',
            fullName: 'GitLab.org / Foo Stage / My very first group',
          },
          {
            id: 'gid://gitlab/Group/2',
            name: 'A new group',
            fullName: 'GitLab.com / Foo Stage / A new group',
          },
          {
            id: 'gid://gitlab/Group/3',
            name: "Third group's the charm",
            fullName: "GitLab.org / Bar Stage / Third group's the charm",
          },
        ],
      },
    },
  },
};

export const todosProjectsResponse = {
  data: {
    projects: {
      nodes: [
        {
          id: 'gid://gitlab/Project/1',
          name: 'My very first project',
          fullPath: 'gitlab-org/foo-stage/my-very-first-group/my-very-first-project',
        },
        {
          id: 'gid://gitlab/Project/2',
          name: 'A new project',
          fullPath: 'gitlab-com/foo-stage/a-new-project',
        },
        {
          id: 'gid://gitlab/Project/3',
          name: "Third project's the charm",
          fullPath: 'gitlab-org/bar-stage/third-projects-the-charm',
        },
      ],
    },
  },
};
