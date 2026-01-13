import { AGENT_PLATFORM_PROJECT_PAGE, AGENT_PLATFORM_USER_PAGE } from '../constants';
import ProjectAgentsPlatformIndex from '../namespace/project/project_agents_platform_index.vue';
import userAgentsPlatformIndex from '../namespace/user/user_agents_platform_index.vue';

export const getNamespaceIndexComponent = (namespace) => {
  if (!namespace) {
    throw new Error(`The namespace argument must be passed to the Vue Router`);
  }

  const componentMappings = {
    [AGENT_PLATFORM_PROJECT_PAGE]: ProjectAgentsPlatformIndex,
    [AGENT_PLATFORM_USER_PAGE]: userAgentsPlatformIndex,
  };

  return componentMappings[namespace];
};

let previousRoute = null;
export const getPreviousRoute = () => previousRoute;
export const setPreviousRoute = (route) => {
  previousRoute = route;
};
