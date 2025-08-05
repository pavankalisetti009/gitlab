import { AGENT_PLATFORM_PROJECT_PAGE } from '../constants';
import ProjectAgentsPlatformIndex from '../namespace/project/project_agents_platform_index.vue';
import { updateActiveNavigation } from './dom_utils';

export const extractNavScopeFromRoute = (route) => {
  // The first matched object is always the top level nav element
  const segments = route?.matched?.[0]?.path?.split('/') || [];
  return segments.length > 1 ? segments[1] : '';
};

export const activeNavigationWatcher = (to, from, next) => {
  const currentScope = extractNavScopeFromRoute(to);
  const oldScope = extractNavScopeFromRoute(from);

  if (!from?.matched.length === 0 || currentScope !== oldScope) {
    updateActiveNavigation(currentScope);
  }

  next();
};

export const getNamespaceIndexComponent = (namespace) => {
  if (!namespace) {
    throw new Error(`The namespace argument must be passed to the Vue Router`);
  }

  const componentMappings = {
    [AGENT_PLATFORM_PROJECT_PAGE]: ProjectAgentsPlatformIndex,
  };

  return componentMappings[namespace];
};
