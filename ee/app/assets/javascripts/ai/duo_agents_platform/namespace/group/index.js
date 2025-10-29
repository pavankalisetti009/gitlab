import { initDuoAgentsPlatformPage } from '../../index';
import { AGENT_PLATFORM_GROUP_PAGE } from '../../constants';

export const initDuoAgentsPlatformGroupPage = () => {
  initDuoAgentsPlatformPage({
    namespace: AGENT_PLATFORM_GROUP_PAGE,
    namespaceDatasetProperties: ['groupPath', 'groupId'],
  });
};
