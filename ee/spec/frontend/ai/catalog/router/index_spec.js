import { createRouter } from 'ee/ai/catalog/router';
import {
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_RUN_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from 'ee/ai/catalog/router/constants';

describe('AI Catalog Router', () => {
  let router;

  const agentId = 1;

  beforeEach(() => {
    router = createRouter();

    // this is needed to disable the warning thrown for incorrect path
    // eslint-disable-next-line no-console
    console.warn = jest.fn();
  });

  describe('/agents/:id redirect', () => {
    it('should redirect /agents/:id to /agents with show query parameter', async () => {
      await router.push(`/agents/${agentId}`);

      expect(router.currentRoute.path).toBe('/agents');
      expect(router.currentRoute.query[AI_CATALOG_SHOW_QUERY_PARAM]).toBe(`${agentId}`);
    });
  });

  describe('/agents/:id/edit', () => {
    it('renders child route', async () => {
      await router.push(`/agents/${agentId}/edit`);

      expect(router.currentRoute.name).toBe(AI_CATALOG_AGENTS_EDIT_ROUTE);
    });
  });

  describe('/agents/:id/run', () => {
    it('renders child route', async () => {
      await router.push(`/agents/${agentId}/run`);

      expect(router.currentRoute.name).toBe(AI_CATALOG_AGENTS_RUN_ROUTE);
    });
  });

  describe('Non-numeric /agents/:id route', () => {
    it('redirects to index for non-numeric id', async () => {
      await router.push('/agents/abc');

      expect(router.currentRoute.path).toBe('/');
    });
  });

  describe('Unknown path fallback', () => {
    it('redirects to index for unknown route', async () => {
      await router.push('/some/unknown/path');

      expect(router.currentRoute.path).toBe('/');
    });
  });
});
