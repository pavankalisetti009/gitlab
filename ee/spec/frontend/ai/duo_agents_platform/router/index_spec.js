import { createRouter } from 'ee/ai/duo_agents_platform/router';

describe('Agents Platform Router', () => {
  let router;
  const baseRoute = '/test-project/-/agents';

  describe('when router is created', () => {
    beforeEach(() => {
      router = createRouter(baseRoute);
    });

    it('configures router with correct base path', () => {
      // Support Vue2 and Vue3
      expect(router.options.base || router.options.history?.base).toBe(baseRoute);
    });
  });

  describe('when router is created with custom base', () => {
    const customBase = '/custom-project/-/agents';

    beforeEach(() => {
      router = createRouter(customBase);
    });

    it('uses the custom base path', () => {
      // Support Vue2 and Vue3
      expect(router.options.base || router.options.history?.base).toBe(customBase);
    });
  });

  describe('catchall redirect', () => {
    it('adds the * redirect path as the last route', () => {
      router = createRouter(baseRoute);
      const { routes } = router.options;
      const lastRoute = routes[routes.length - 1];

      // In Vue3, the received result is "/:pathMatch(.*)*"
      expect(lastRoute.path.endsWith('*')).toBe(true);
      expect(lastRoute.redirect).toBe('/agent-sessions');
      expect(lastRoute.name).toBeUndefined();
    });
  });
});
