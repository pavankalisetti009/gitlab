import { GlBreakpointInstance } from '@gitlab/ui/src/utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import AIPanel from 'ee/ai/components/ai_panel.vue';
import AiContentContainer from 'ee/ai/components/content_container.vue';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import AgentSessionsRoot from '~/vue_shared/spa/components/spa_root.vue';
import DuoAgenticChat from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat.vue';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';

describe('AIPanel', () => {
  useLocalStorageSpy();
  let wrapper;
  let mockRouter;

  const createComponent = ({
    activeTab = 'chat',
    isExpanded = true,
    routeName = 'some_route',
    routePath = '/some-path',
    routeParams = {},
    propsData = {},
  } = {}) => {
    mockRouter = {
      push: jest.fn(),
    };

    wrapper = shallowMountExtended(AIPanel, {
      propsData: {
        projectId: 'gid://gitlab/Project/123',
        namespaceId: 'gid://gitlab/Group/456',
        rootNamespaceId: 'gid://gitlab/Group/789',
        resourceId: 'gid://gitlab/Resource/111',
        metadata: '{"key":"value"}',
        userModelSelectionEnabled: false,
        ...propsData,
      },
      data() {
        return {
          activeTab,
          isExpanded,
        };
      },
      mocks: {
        $router: mockRouter,
        $route: {
          name: routeName,
          path: routePath,
          params: routeParams,
        },
      },
      stubs: {
        AiContentContainer,
        NavigationRail,
        DuoAgenticChat,
      },
    });
  };

  const findContentContainer = () => wrapper.findComponent(AiContentContainer);
  const findNavigationRail = () => wrapper.findComponent(NavigationRail);
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);

  it('renders content container and navigation rail', () => {
    createComponent();
    expect(findContentContainer().exists()).toBe(true);
    expect(findNavigationRail().exists()).toBe(true);
  });

  it('syncs expansion state via localStorage when updated by local-storage-sync', async () => {
    createComponent();
    findLocalStorageSync().vm.$emit('input', false);
    await waitForPromises();

    expect(findNavigationRail().props('isExpanded')).toBe(false);
  });

  it('emits collapse and clears tab when the active tab is toggled again', async () => {
    createComponent({ activeTab: 'chat' });
    findNavigationRail().vm.$emit('handleTabToggle', 'chat');
    await waitForPromises();

    expect(findContentContainer().exists()).toBe(false);
  });

  it('activates new tab and expands if collapsed', async () => {
    createComponent({ activeTab: null, isExpanded: false });
    findNavigationRail().vm.$emit('handleTabToggle', 'suggestions');

    await waitForPromises();

    expect(findContentContainer().exists()).toBe(true);
    expect(findContentContainer().props('activeTab')).toEqual({
      title: 'Suggestions',
      component: 'Suggestions content placeholder',
    });
    expect(findContentContainer().props('isExpanded')).toBe(true);
  });

  describe('when chat tab is active', () => {
    it('returns chat tab configuration with DuoAgenticChat component', () => {
      createComponent({ activeTab: 'chat' });

      expect(findContentContainer().props('activeTab')).toEqual({
        title: 'GitLab Duo Agentic Chat',
        component: DuoAgenticChat,
      });
    });
  });

  describe('when sessions tab is active', () => {
    it('returns sessions tab configuration with AgentSessions component', () => {
      createComponent({ activeTab: 'sessions' });

      expect(findContentContainer().props('activeTab')).toEqual({
        title: 'Sessions',
        component: AgentSessionsRoot,
        initialRoute: '/agent-sessions',
      });
    });

    describe('when on agents platform show route', () => {
      it('formats session title with agent flow name', () => {
        createComponent({
          activeTab: 'sessions',
          routeName: AGENTS_PLATFORM_SHOW_ROUTE,
          routeParams: { id: '123' },
        });

        expect(findContentContainer().props('activeTab').title).toBe('Agent session #123');
      });
    });

    describe('when not on agents platform show route', () => {
      it('uses default Sessions title', () => {
        createComponent({
          activeTab: 'sessions',
          routeName: 'some_other_route',
        });

        expect(findContentContainer().props('activeTab').title).toBe('Sessions');
      });
    });
  });

  describe('showBackButton computed property', () => {
    describe('when current tab has initialRoute and route path differs', () => {
      it('shows back button', () => {
        createComponent({
          activeTab: 'sessions',
          routePath: '/agent-sessions/123',
        });

        expect(findContentContainer().props('showBackButton')).toBe(true);
      });
    });

    describe('when current tab has initialRoute but route path matches', () => {
      it('does not show back button', () => {
        createComponent({
          activeTab: 'sessions',
          routePath: '/agent-sessions',
        });

        expect(findContentContainer().props('showBackButton')).toBe(false);
      });
    });

    describe('when current tab has no initialRoute', () => {
      it('does not show back button', () => {
        createComponent({
          activeTab: 'chat',
          routePath: '/some-path',
        });

        expect(findContentContainer().props('showBackButton')).toBe(false);
      });
    });
  });

  describe('handleGoBack method', () => {
    describe('when current tab has initialRoute', () => {
      it('navigates to initial route', async () => {
        createComponent({
          activeTab: 'sessions',
          routePath: '/agent-sessions/123',
        });

        findContentContainer().vm.$emit('go-back');
        await waitForPromises();

        expect(mockRouter.push).toHaveBeenCalledWith('/agent-sessions');
      });
    });

    describe('when current tab has no initialRoute', () => {
      it('does not navigate', async () => {
        createComponent({
          activeTab: 'chat',
        });

        findContentContainer().vm.$emit('go-back');
        await waitForPromises();

        expect(mockRouter.push).not.toHaveBeenCalled();
      });
    });
  });

  describe('on window resize', () => {
    const triggerResize = () => {
      window.dispatchEvent(new Event('resize'));
    };

    it('collapses panel and clears the tab when resizing from desktop to non-desktop', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      createComponent();

      GlBreakpointInstance.isDesktop.mockReturnValue(false);
      triggerResize();
      await waitForPromises();

      expect(findNavigationRail().props('isExpanded')).toBe(false);
      expect(findContentContainer().exists()).toBe(false);
    });

    it('does not change panel state when resizing from non-desktop to desktop', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(false);
      createComponent({ activeTab: null, isExpanded: false });

      triggerResize();
      GlBreakpointInstance.isDesktop.mockReturnValue(true);
      await waitForPromises();

      expect(findNavigationRail().props('isExpanded')).toBe(false);
      expect(findContentContainer().exists()).toBe(false);
    });

    it('does not change panel state when breakpoint size does not change', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      createComponent();

      triggerResize();
      await waitForPromises();

      expect(findNavigationRail().props('isExpanded')).toBe(true);
      expect(findContentContainer().exists()).toBe(true);
      expect(findContentContainer().props('activeTab').title).toBe('GitLab Duo Agentic Chat');
    });
  });

  describe('props passing', () => {
    it('passes all props to content container', () => {
      createComponent({
        activeTab: 'chat',
        propsData: {
          projectId: 'gid://gitlab/Project/999',
          namespaceId: 'gid://gitlab/Group/888',
          rootNamespaceId: 'gid://gitlab/Group/777',
          resourceId: 'gid://gitlab/Resource/666',
          metadata: '{"test":"data"}',
          userModelSelectionEnabled: true,
        },
      });

      expect(findContentContainer().props()).toMatchObject({
        projectId: 'gid://gitlab/Project/999',
        namespaceId: 'gid://gitlab/Group/888',
        rootNamespaceId: 'gid://gitlab/Group/777',
        resourceId: 'gid://gitlab/Resource/666',
        metadata: '{"test":"data"}',
        userModelSelectionEnabled: true,
      });
    });
  });
});
