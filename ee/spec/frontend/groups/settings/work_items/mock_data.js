export const mockNamespaceMetadata = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/24',
      linkPaths: {
        groupIssues: '/groups/gitlab-org/-/issues',
        __typename: 'GroupNamespaceLinks',
      },
      __typename: 'Namespace',
    },
  },
};

export const deleteStatusErrorResponse = {
  data: {
    lifecycleUpdate: {
      lifecycle: null,
      errors: ["Cannot delete status 'In progress' because it is in use"],
      __typename: 'LifecycleUpdatePayload',
    },
  },
};
