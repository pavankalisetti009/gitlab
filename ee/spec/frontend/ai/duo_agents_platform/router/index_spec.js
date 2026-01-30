import { createRouter } from 'ee/ai/duo_agents_platform/router';
import * as utils from 'ee/ai/duo_agents_platform/router/utils';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
} from 'ee/ai/catalog/router/constants';

describe('Agents Platform Router', () => {
  let router;
  const baseRoute = '/test-project/-/agents';
  const id = 1;

  beforeEach(() => {
    gon.features = {
      aiCatalogFlows: false,
    };
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

  describe('triggers', () => {
    it('redirect to triggers base route when ID to edit does not exist', async () => {
      router = createRouter(baseRoute, 'project');
      await router.push('/triggers/invalid-id/edit');

      expect(router.currentRoute.path).toBe('/triggers');
    });

    describe('triggers new route', () => {
      it.each`
        readAiCatalogThirdPartyFlow | createAiCatalogThirdPartyFlow | readAiCatalogFlow | expectedPath
        ${true}                     | ${false}                      | ${false}          | ${'/triggers/new'}
        ${false}                    | ${true}                       | ${false}          | ${'/triggers/new'}
        ${false}                    | ${false}                      | ${true}           | ${'/triggers/new'}
        ${false}                    | ${false}                      | ${false}          | ${'/agent-sessions'}
      `(
        'navigates to $expectedPath when readAiCatalogThirdPartyFlow=$readAiCatalogThirdPartyFlow, createAiCatalogThirdPartyFlow=$createAiCatalogThirdPartyFlow, readAiCatalogFlow=$readAiCatalogFlow',
        async ({
          readAiCatalogThirdPartyFlow,
          createAiCatalogThirdPartyFlow,
          readAiCatalogFlow,
          expectedPath,
        }) => {
          gon.abilities = {
            readAiCatalogThirdPartyFlow,
            createAiCatalogThirdPartyFlow,
            readAiCatalogFlow,
          };
          router = createRouter(baseRoute, 'project');

          await router.push('/triggers/new');

          expect(router.currentRoute.path).toBe(expectedPath);
        },
      );
    });
  });

  describe('agents', () => {
    beforeEach(() => {
      router = createRouter(baseRoute, 'project');
    });

    it('redirect to agents base route when path does not exist', async () => {
      await router.push('/agents/invalid');

      expect(router.currentRoute.path).toBe('/agents');
    });

    it('includes agents routes', () => {
      const { routes } = router.options;
      const agentsRoute = routes.find((route) => route.path === '/agents');

      expect(agentsRoute).toBeDefined();
    });

    describe('agents child routes', () => {
      it.each`
        testName              | path                         | expectedRouteName
        ${'agents index'}     | ${'/agents'}                 | ${AI_CATALOG_AGENTS_ROUTE}
        ${'agents new'}       | ${'/agents/new'}             | ${AI_CATALOG_AGENTS_NEW_ROUTE}
        ${'agents show'}      | ${`/agents/${id}`}           | ${AI_CATALOG_AGENTS_SHOW_ROUTE}
        ${'agents edit'}      | ${`/agents/${id}/edit`}      | ${AI_CATALOG_AGENTS_EDIT_ROUTE}
        ${'agents duplicate'} | ${`/agents/${id}/duplicate`} | ${AI_CATALOG_AGENTS_DUPLICATE_ROUTE}
      `('renders $testName child route', async ({ path, expectedRouteName }) => {
        await router.push(path);

        expect(router.currentRoute.name).toBe(expectedRouteName);
      });
    });
  });

  describe('flows routes', () => {
    describe('when aiCatalogFlows is enabled', () => {
      beforeEach(() => {
        gon.features = {
          aiCatalogFlows: true,
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

      describe('flows child routes', () => {
        beforeEach(() => {
          gon.features = {
            aiCatalogFlows: true,
            aiCatalogThirdPartyFlows: true,
          };
          router = createRouter(baseRoute, 'project');
        });

        it.each`
          testName             | path                        | expectedRouteName
          ${'flows index'}     | ${'/flows'}                 | ${AI_CATALOG_FLOWS_ROUTE}
          ${'flows new'}       | ${'/flows/new'}             | ${AI_CATALOG_FLOWS_NEW_ROUTE}
          ${'flows show'}      | ${`/flows/${id}`}           | ${AI_CATALOG_FLOWS_SHOW_ROUTE}
          ${'flows edit'}      | ${`/flows/${id}/edit`}      | ${AI_CATALOG_FLOWS_EDIT_ROUTE}
          ${'flows duplicate'} | ${`/flows/${id}/duplicate`} | ${AI_CATALOG_FLOWS_DUPLICATE_ROUTE}
        `('renders $testName child route', async ({ path, expectedRouteName }) => {
          await router.push(path);

          expect(router.currentRoute.name).toBe(expectedRouteName);
        });
      });
    });

    describe('when aiCatalogFlows is disabled', () => {
      beforeEach(() => {
        gon.features = {
          aiCatalogFlows: false,
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

  describe('beforeEach hook', () => {
    beforeEach(() => {
      jest.spyOn(utils, 'setPreviousRoute');
      router = createRouter(baseRoute, 'project');
    });

    it('calls setPreviousRoute when from route has a name', async () => {
      await router.push('/agents');
      await router.push('/agents/new');

      expect(utils.setPreviousRoute).toHaveBeenCalledWith(
        expect.objectContaining({
          name: AI_CATALOG_AGENTS_ROUTE,
        }),
      );
    });

    it('does not call setPreviousRoute when from route has no name', async () => {
      await router.push('/invalid-path');

      expect(utils.setPreviousRoute).not.toHaveBeenCalled();
    });
  });

  describe('afterEach hook - page titles', () => {
    const originalTitle = 'Automate · GitLab';

    beforeEach(() => {
      document.title = originalTitle;
      gon.features = {
        aiCatalogFlows: true,
      };
      router = createRouter(baseRoute, 'project');
    });

    it('sets document title for agents route', async () => {
      await router.push('/agents');

      expect(document.title).toBe('Agents · Automate · GitLab');
    });

    it('sets document title for new agent route', async () => {
      await router.push('/agents/new');

      expect(document.title).toBe('New agent · Automate · GitLab');
    });

    it('sets document title for flows route', async () => {
      await router.push('/flows');

      expect(document.title).toBe('Flows · Automate · GitLab');
    });

    it('sets document title for new flow route', async () => {
      await router.push('/flows/new');

      expect(document.title).toBe('New flow · Automate · GitLab');
    });

    it('sets document title for triggers route', async () => {
      await router.push('/triggers');

      expect(document.title).toBe('Triggers · Automate · GitLab');
    });

    it('sets document title for agent-sessions route', async () => {
      await router.push('/agent-sessions');

      expect(document.title).toBe('Sessions · Automate · GitLab');
    });

    it('does not set document title for flow routes with useId meta', async () => {
      await router.push('/flows');
      const titleAfterFlows = document.title;

      await router.push(`/flows/${id}`);

      expect(document.title).toBe(titleAfterFlows);
    });

    it('does not set document title for agent routes with useId meta', async () => {
      await router.push('/agents');
      const titleAfterAgents = document.title;

      await router.push(`/agents/${id}`);

      expect(document.title).toBe(titleAfterAgents);
    });
  });
});
