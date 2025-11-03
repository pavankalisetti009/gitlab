import { initDuoAgentsPlatformPage } from '../../index';
import { AGENT_PLATFORM_PROJECT_PAGE } from '../../constants';

export const initDuoAgentsPlatformProjectPage = () => {
  initDuoAgentsPlatformPage({
    namespace: AGENT_PLATFORM_PROJECT_PAGE,
    namespaceDatasetProperties: ['projectPath', 'projectId', 'rootGroupId'],
  });
};
