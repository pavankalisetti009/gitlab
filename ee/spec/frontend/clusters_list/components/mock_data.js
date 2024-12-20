import {
  clusterAgentsResponse as clusterAgentsResponseCE,
  treeListResponseData as treeListResponseDataCE,
  expectedAgentsList as expectedAgentsListCE,
} from 'jest/clusters_list/components/mock_data';
import { agent, tokens, connections } from 'jest/clusters_list/mocks/apollo';

function extendAgentsWithReceptiveField() {
  const response = JSON.parse(JSON.stringify(clusterAgentsResponseCE));
  const { project } = response.data;

  const addReceptiveField = (agentNode) => ({ ...agentNode, isReceptive: false });

  const updateAgents = (agentList) =>
    agentList.map((item) =>
      item.agent ? { agent: addReceptiveField(item.agent) } : addReceptiveField(item),
    );

  project.clusterAgents.nodes = updateAgents(project.clusterAgents.nodes);
  project.ciAccessAuthorizedAgents.nodes = updateAgents(project.ciAccessAuthorizedAgents.nodes);
  project.userAccessAuthorizedAgents.nodes = updateAgents(project.userAccessAuthorizedAgents.nodes);

  return response;
}

export const clusterAgentsResponse = extendAgentsWithReceptiveField();

export const treeListResponseData = treeListResponseDataCE;

export const expectedAgentsList = expectedAgentsListCE;

export const createAgentResponse = {
  data: {
    createClusterAgent: {
      clusterAgent: {
        ...agent,
        isReceptive: false,
        connections,
        tokens,
      },
      errors: [],
    },
  },
};

export const createAgentErrorResponse = {
  data: {
    createClusterAgent: {
      clusterAgent: {
        ...agent,
        isReceptive: false,
        connections,
        tokens,
      },
      errors: ['could not create agent'],
    },
  },
};

export const getAgentResponse = {
  data: {
    project: {
      __typename: 'Project',
      id: 'project-1',
      clusterAgents: { nodes: [{ ...agent, isReceptive: false, connections, tokens }] },
      ciAccessAuthorizedAgents: { nodes: [] },
      userAccessAuthorizedAgents: { nodes: [] },
      repository: {
        tree: {
          trees: { nodes: [{ ...agent, path: null }] },
        },
      },
    },
  },
};
