import { createRouter } from 'ee/ai/catalog/router';
import { AI_CATALOG_SHOW_QUERY_PARAM } from 'ee/ai/catalog/router/constants';

describe('AI Catalog Router', () => {
  let router;

  const agentId = 1;

  beforeEach(() => {
    router = createRouter();
  });

  describe('agents/:id redirect', () => {
    it('should redirect /agents/:id to /agents with show query parameter', async () => {
      await router.push(`/agents/${agentId}`);

      expect(router.currentRoute.path).toBe('/agents');
      expect(router.currentRoute.query[AI_CATALOG_SHOW_QUERY_PARAM]).toBe(`${agentId}`);
    });
  });
});
