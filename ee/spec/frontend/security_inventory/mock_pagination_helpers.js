import { subgroupsAndProjects } from './mock_data';

export const mockData = subgroupsAndProjects.data;

export const createGroupResponse = ({
  subgroups = mockData.group.descendantGroups.nodes || [],
  projects = mockData.group.projects.nodes || [],
  namespaceSecurityProjects = mockData.namespaceSecurityProjects.edges || [],
  subgroupsPageInfo = { hasNextPage: false, endCursor: null },
  projectsPageInfo = { hasNextPage: false, endCursor: null },
} = {}) => {
  const result = {
    data: {
      group: {
        ...mockData.group,
        descendantGroups: {
          nodes: subgroups,
          pageInfo: subgroupsPageInfo,
        },
        projects: {
          nodes: projects,
          pageInfo: projectsPageInfo,
        },
      },
      namespaceSecurityProjects: {
        edges: namespaceSecurityProjects,
        pageInfo: projectsPageInfo,
      },
    },
  };
  return result;
};

export const createPaginatedHandler = ({ first, second }) => {
  const handler = jest.fn();
  handler.mockResolvedValueOnce(createGroupResponse(first));
  handler.mockResolvedValueOnce(createGroupResponse(second));
  return handler;
};
