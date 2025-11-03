import { getStorageValue, saveStorageValue, removeStorageValue } from '~/lib/utils/local_storage';
import { AGENTS_PLATFORM_INDEX_ROUTE } from '../router/constants';

const BASE_STORAGE_KEY = 'duo_agents_platform_last_route';

export const getStorageKey = (context) =>
  context ? `${BASE_STORAGE_KEY}_${context}` : BASE_STORAGE_KEY;

export const getLastRouteState = (storageKey = BASE_STORAGE_KEY) => {
  const { exists, value } = getStorageValue(storageKey);
  return exists ? value : null;
};

export const saveRouteState = (route, storageKey = BASE_STORAGE_KEY) => {
  if (route.name) {
    saveStorageValue(storageKey, {
      name: route.name,
      params: route.params || {},
    });
  }
};

export const clearRouteState = (storageKey = BASE_STORAGE_KEY) => {
  removeStorageValue(storageKey);
};

export const restoreLastRoute = (router, options = {}) => {
  const { defaultRoute = AGENTS_PLATFORM_INDEX_ROUTE, context = null, storageKey = null } = options;
  const key = storageKey || getStorageKey(context);
  const routeState = getLastRouteState(key) || { name: defaultRoute };

  return router.push(routeState).catch(() => {
    clearRouteState(key);
    return router.push({ name: defaultRoute });
  });
};

export const setupNavigationGuards = ({ router, context = null, storageKey = null }) => {
  const key = storageKey || getStorageKey(context);
  router.afterEach((to) => {
    saveRouteState(to, key);
  });
};
