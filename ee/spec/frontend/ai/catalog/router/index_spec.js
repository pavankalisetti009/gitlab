import { createRouter } from 'ee/ai/catalog/router';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
} from 'ee/ai/catalog/router/constants';
import { isLoggedIn } from '~/lib/utils/common_utils';

jest.mock('~/lib/utils/common_utils');

describe('AI Catalog Router', () => {
  let router;

  const agentId = 1;
  const flowId = 1;

  beforeEach(() => {
    isLoggedIn.mockReturnValue(true);
    router = createRouter();

    // this is needed to disable the warning thrown for incorrect path
    // eslint-disable-next-line no-console
    console.warn = jest.fn();
  });

  describe('Agent child routes', () => {
    it.each`
      testName              | path                              | expectedRouteName
      ${'agents index'}     | ${'/agents'}                      | ${AI_CATALOG_AGENTS_ROUTE}
      ${'agents new'}       | ${'/agents/new'}                  | ${AI_CATALOG_AGENTS_NEW_ROUTE}
      ${'agents show'}      | ${`/agents/${agentId}`}           | ${AI_CATALOG_AGENTS_SHOW_ROUTE}
      ${'agents edit'}      | ${`/agents/${agentId}/edit`}      | ${AI_CATALOG_AGENTS_EDIT_ROUTE}
      ${'agents duplicate'} | ${`/agents/${agentId}/duplicate`} | ${AI_CATALOG_AGENTS_DUPLICATE_ROUTE}
    `('renders $testName child route', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });
  });

  describe('When aiCatalogFlows feature flag is on', () => {
    beforeEach(() => {
      gon.features = {
        aiCatalogFlows: true,
        aiCatalogThirdPartyFlows: false,
      };
      router = createRouter();
    });

    it.each`
      testName             | path                            | expectedRouteName
      ${'flows index'}     | ${'/flows'}                     | ${AI_CATALOG_FLOWS_ROUTE}
      ${'flows show'}      | ${`/flows/${agentId}`}          | ${AI_CATALOG_FLOWS_SHOW_ROUTE}
      ${'flows new'}       | ${'/flows/new'}                 | ${AI_CATALOG_FLOWS_NEW_ROUTE}
      ${'flows edit'}      | ${`/flows/${flowId}/edit`}      | ${AI_CATALOG_FLOWS_EDIT_ROUTE}
      ${'flows duplicate'} | ${`/flows/${flowId}/duplicate`} | ${AI_CATALOG_FLOWS_DUPLICATE_ROUTE}
    `('renders $testName child route', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });
  });

  describe('When aiCatalogThirdPartyFlows feature flag is on', () => {
    beforeEach(() => {
      gon.features = {
        aiCatalogFlows: false,
        aiCatalogThirdPartyFlows: true,
      };
      router = createRouter();
    });

    it.each`
      testName             | path                            | expectedRouteName
      ${'flows index'}     | ${'/flows'}                     | ${AI_CATALOG_FLOWS_ROUTE}
      ${'flows show'}      | ${`/flows/${agentId}`}          | ${AI_CATALOG_FLOWS_SHOW_ROUTE}
      ${'flows new'}       | ${'/flows/new'}                 | ${AI_CATALOG_FLOWS_NEW_ROUTE}
      ${'flows edit'}      | ${`/flows/${flowId}/edit`}      | ${AI_CATALOG_FLOWS_EDIT_ROUTE}
      ${'flows duplicate'} | ${`/flows/${flowId}/duplicate`} | ${AI_CATALOG_FLOWS_DUPLICATE_ROUTE}
    `('renders $testName child route', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });
  });

  describe('When both flow feature flags are on', () => {
    beforeEach(() => {
      gon.features = {
        aiCatalogFlows: true,
        aiCatalogThirdPartyFlows: true,
      };
      router = createRouter();
    });

    it.each`
      testName             | path                            | expectedRouteName
      ${'flows index'}     | ${'/flows'}                     | ${AI_CATALOG_FLOWS_ROUTE}
      ${'flows show'}      | ${`/flows/${agentId}`}          | ${AI_CATALOG_FLOWS_SHOW_ROUTE}
      ${'flows new'}       | ${'/flows/new'}                 | ${AI_CATALOG_FLOWS_NEW_ROUTE}
      ${'flows edit'}      | ${`/flows/${flowId}/edit`}      | ${AI_CATALOG_FLOWS_EDIT_ROUTE}
      ${'flows duplicate'} | ${`/flows/${flowId}/duplicate`} | ${AI_CATALOG_FLOWS_DUPLICATE_ROUTE}
    `('renders $testName child route', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });
  });

  describe('When both flow feature flags are off', () => {
    beforeEach(() => {
      gon.features = {
        aiCatalogFlows: false,
        aiCatalogThirdPartyFlows: false,
      };
      router = createRouter();
    });

    it.each`
      testName             | path                            | expectedRouteName
      ${'flows index'}     | ${'/flows'}                     | ${AI_CATALOG_AGENTS_ROUTE}
      ${'flows show'}      | ${`/flows/${agentId}`}          | ${AI_CATALOG_AGENTS_ROUTE}
      ${'flows new'}       | ${'/flows/new'}                 | ${AI_CATALOG_AGENTS_ROUTE}
      ${'flows edit'}      | ${`/flows/${flowId}/edit`}      | ${AI_CATALOG_AGENTS_ROUTE}
      ${'flows duplicate'} | ${`/flows/${flowId}/duplicate`} | ${AI_CATALOG_AGENTS_ROUTE}
    `('renders $testName child route', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });
  });

  describe('Non-numeric ID routes', () => {
    it.each`
      type        | path
      ${'agents'} | ${'/agents/abc'}
      ${'flows'}  | ${'/flows/abc'}
    `('redirects to index for non-numeric $type id', async ({ path }) => {
      await router.push(path);

      expect(router.currentRoute.path).toMatch(/^\/agents\/?$/);
    });
  });

  describe('When user is not logged in', () => {
    beforeEach(() => {
      gon.features = {
        aiCatalogFlows: true,
      };
      router = createRouter();
      isLoggedIn.mockReturnValue(false);
    });

    it.each`
      testName              | path
      ${'agents new'}       | ${'/agents/new'}
      ${'agents edit'}      | ${`/agents/${agentId}/edit`}
      ${'agents duplicate'} | ${`/agents/${agentId}/duplicate`}
      ${'flows new'}        | ${'/flows/new'}
      ${'flows edit'}       | ${`/flows/${flowId}/edit`}
      ${'flows duplicate'}  | ${`/flows/${flowId}/duplicate`}
    `('redirects $testName route to index when not logged in', async ({ path }) => {
      try {
        await router.push(path);
      } catch (error) {
        // intentionally blank
        //
        // * in Vue.js 2 this will trigger "redundant navigation" error and will be caught here
      }

      expect(router.currentRoute.path).toMatch(/^\/agents\/?$/);
    });

    it.each`
      testName          | path         | expectedRouteName
      ${'index route'}  | ${''}        | ${AI_CATALOG_AGENTS_ROUTE}
      ${'agents index'} | ${`/agents`} | ${AI_CATALOG_AGENTS_ROUTE}
      ${'flows index'}  | ${`/flows`}  | ${AI_CATALOG_FLOWS_ROUTE}
    `('lets the user enter the page', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });
  });

  describe('Unknown path fallback', () => {
    it('redirects to index for unknown route', async () => {
      await router.push('/some/unknown/path');

      expect(router.currentRoute.path).toMatch(/^\/agents\/?$/);
    });
  });
});
