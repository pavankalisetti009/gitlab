import {
  clusterAgentsResponse as clusterAgentsResponseCE,
  treeListResponseData as treeListResponseDataCE,
  expectedAgentsList as expectedAgentsListCE,
} from 'jest/clusters_list/components/mock_data';

function extendAgentsWithReceptiveField() {
  const response = JSON.parse(JSON.stringify(clusterAgentsResponseCE));
  const { project } = response.data;

  const addReceptiveField = (agent) => ({ ...agent, isReceptive: false });

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
