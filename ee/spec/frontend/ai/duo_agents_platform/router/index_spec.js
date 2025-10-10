import { createRouter } from 'ee/ai/duo_agents_platform/router';
import * as utils from 'ee/ai/duo_agents_platform/router/utils';

describe('Agents Platform Router', () => {
  let router;
  const baseRoute = '/test-project/-/agents';

  beforeEach(() => {
    gon.features = {
      aiCatalogFlows: false,
      aiCatalogThirdPartyFlows: false,
    };

    // this is needed to disable the warning thrown for incorrect path
    // eslint-disable-next-line no-console
    console.warn = jest.fn();
  });

  describe('when router is created', () => {
    beforeEach(() => {
      router = createRouter(baseRoute, 'project');
    });

    it('configures router with correct base path', () => {
      // Support Vue2 and Vue3
      expect(router.options.base || router.options.history?.base).toBe(baseRoute);
    });
  });

  describe('when router is created with custom base', () => {
    const customBase = '/custom-project/-/agents';

    beforeEach(() => {
      router = createRouter(customBase, 'group');
    });

    it('uses the custom base path', () => {
      // Support Vue2 and Vue3
      expect(router.options.base || router.options.history?.base).toBe(customBase);
    });
  });

  describe('namespace logic', () => {
    beforeEach(() => {
      jest.spyOn(utils, 'getNamespaceIndexComponent');
      router = createRouter(baseRoute, 'group');
    });

    it('calls getNamespaceIndexComponent with the namespace', () => {
      expect(utils.getNamespaceIndexComponent).toHaveBeenCalledWith('group');
    });
  });

  describe('flow triggers', () => {
    it('redirect to flow triggers base route when ID to edit does not exist', async () => {
      router = createRouter(baseRoute, 'project');
      await router.push('/flow-triggers/invalid-id/edit');

      expect(router.currentRoute.path).toBe('/flow-triggers');
    });
  });

  describe('agents', () => {
    it('redirect to agents base route when path does not exist', async () => {
      router = createRouter(baseRoute, 'project');
      await router.push('/agents/invalid');

      expect(router.currentRoute.path).toBe('/agents');
    });
  });

  describe('flows routes', () => {
    describe('when aiCatalogFlows is enabled', () => {
      beforeEach(() => {
        gon.features = {
          aiCatalogFlows: true,
          aiCatalogThirdPartyFlows: false,
        };
      });

      it('includes flows routes', () => {
        router = createRouter(baseRoute, 'project');
        const { routes } = router.options;
        const flowsRoute = routes.find((route) => route.path === '/flows');

        expect(flowsRoute).toBeDefined();
      });

      it('redirect to flows base route when path does not exist', async () => {
        router = createRouter(baseRoute, 'project');
        await router.push('/flows/invalid');

        expect(router.currentRoute.path).toBe('/flows');
      });
    });

    describe('when aiCatalogThirdPartyFlows is enabled', () => {
      beforeEach(() => {
        gon.features = {
          aiCatalogFlows: false,
          aiCatalogThirdPartyFlows: true,
        };
      });

      it('includes flows routes', () => {
        router = createRouter(baseRoute, 'project');
        const { routes } = router.options;
        const flowsRoute = routes.find((route) => route.path === '/flows');

        expect(flowsRoute).toBeDefined();
      });

      it('redirect to flows base route when path does not exist', async () => {
        router = createRouter(baseRoute, 'project');
        await router.push('/flows/invalid');

        expect(router.currentRoute.path).toBe('/flows');
      });
    });

    describe('when both aiCatalogFlows and aiCatalogThirdPartyFlows are enabled', () => {
      beforeEach(() => {
        gon.features = {
          aiCatalogFlows: true,
          aiCatalogThirdPartyFlows: true,
        };
      });

      it('includes flows routes', () => {
        router = createRouter(baseRoute, 'project');
        const { routes } = router.options;
        const flowsRoute = routes.find((route) => route.path === '/flows');

        expect(flowsRoute).toBeDefined();
      });

      it('redirect to flows base route when path does not exist', async () => {
        router = createRouter(baseRoute, 'project');
        await router.push('/flows/invalid');

        expect(router.currentRoute.path).toBe('/flows');
      });
    });

    describe('when both feature flags are disabled', () => {
      beforeEach(() => {
        gon.features = {
          aiCatalogFlows: false,
          aiCatalogThirdPartyFlows: false,
        };
      });

      it('does not include flows routes', () => {
        router = createRouter(baseRoute, 'project');
        const { routes } = router.options;
        const flowsRoute = routes.find((route) => route.path === '/flows');

        expect(flowsRoute).toBeUndefined();
      });

      it('redirects to agent sessions when trying to access flows', async () => {
        router = createRouter(baseRoute, 'project');
        await router.push('/flows');

        expect(router.currentRoute.path).toBe('/agent-sessions');
      });
    });
  });

  describe('catchall redirect', () => {
    it('adds the * redirect path as the last route', () => {
      router = createRouter(baseRoute, 'project');
      const { routes } = router.options;
      const lastRoute = routes[routes.length - 1];

      // In Vue3, the received result is "/:pathMatch(.*)*"
      expect(lastRoute.path.endsWith('*')).toBe(true);
      expect(lastRoute.redirect).toBe('/agent-sessions');
      expect(lastRoute.name).toBeUndefined();
    });
  });
});
