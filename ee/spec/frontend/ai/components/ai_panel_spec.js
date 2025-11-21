import { GlBreakpointInstance } from '@gitlab/ui/src/utils';
import { nextTick } from 'vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { setHTMLFixture } from 'helpers/fixtures';
import AIPanel from 'ee/ai/components/ai_panel.vue';
import AiContentContainer from 'ee/ai/components/content_container.vue';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';
import AgentSessionsRoot from '~/vue_shared/spa/components/spa_root.vue';
import DuoAgenticChat from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat.vue';
import DuoChat from 'ee/ai/tanuki_bot/components/duo_chat.vue';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { CHAT_MODES } from 'ee/ai/tanuki_bot/constants';
import Cookies from '~/lib/utils/cookies';
import { duoChatGlobalState } from '~/super_sidebar/constants';

const aiPanelStateCookie = 'ai_panel_active_tab';

describe('AiPanel', () => {
  let wrapper;
  let mockRouter;

  const getContentComponentMock = jest.fn();

  const createComponent = ({
    routeName = 'some_route',
    routePath = '/some-path',
    routeParams = {},
    propsData = {},
    provide = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    mockRouter = {
      push: jest.fn().mockResolvedValue(),
    };

    wrapper = mountFn(AIPanel, {
      propsData: {
        userId: 'gid://gitlab/User/1',
        projectId: 'gid://gitlab/Project/123',
        namespaceId: 'gid://gitlab/Group/456',
        rootNamespaceId: 'gid://gitlab/Group/789',
        resourceId: 'gid://gitlab/Resource/111',
        metadata: '{"key":"value"}',
        userModelSelectionEnabled: false,
        ...propsData,
      },
      provide: {
        isAgenticAvailable: true,
        chatTitle: null,
        chatConfiguration: {
          agenticTitle: 'GitLab Duo Agentic Chat',
          classicTitle: 'GitLab Duo Chat',
          agenticComponent: DuoAgenticChat,
          classicComponent: DuoChat,
          defaultProps: {
            isAgenticAvailable: true,
            isEmbedded: true,
            showStudioHeader: true,
          },
        },
        ...provide,
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
        AiContentContainer: stubComponent(AiContentContainer, {
          methods: {
            getContentComponent: getContentComponentMock,
          },
        }),
        NavigationRail,
        DuoAgenticChat,
      },
    });
  };

  const findContentContainer = () => wrapper.findComponent(AiContentContainer);
  const findNavigationRail = () => wrapper.findComponent(NavigationRail);
  const findPageLayout = () => document.querySelector('.js-page-layout');

  beforeEach(() => {
    setHTMLFixture(`<div class="js-page-layout"></div>`);
    Cookies.remove(aiPanelStateCookie);
    // Reset global state before each test
    duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
    duoChatGlobalState.activeTab = null;
    duoChatGlobalState.lastRoutePerTab = {};
  });

  it('renders initial collapsed state', () => {
    createComponent();
    expect(findContentContainer().exists()).toBe(false);
    expect(findNavigationRail().exists()).toBe(true);
  });

  describe('panel opened state', () => {
    it('restores the state from a cookie', () => {
      Cookies.set(aiPanelStateCookie, 'chat');
      createComponent();
      expect(findContentContainer().props('activeTab')).toEqual({
        title: 'GitLab Duo Agentic Chat',
        component: DuoAgenticChat,
        props: {
          mode: 'active',
          isAgenticAvailable: true,
          isEmbedded: true,
          showStudioHeader: true,
        },
      });
    });

    it('stores the state when window is focused', () => {
      Cookies.set(aiPanelStateCookie, 'chat');
      createComponent();
      Cookies.set(aiPanelStateCookie, 'sessions');
      window.dispatchEvent(new FocusEvent('focus'));
      expect(Cookies.get(aiPanelStateCookie)).toBe('chat');
    });

    it('opens a panel', async () => {
      createComponent();
      findNavigationRail().vm.$emit('handleTabToggle', 'suggestions');
      await nextTick();
      expect(findContentContainer().exists()).toBe(true);
      expect(Cookies.get(aiPanelStateCookie)).toBe('suggestions');
    });

    it('closes a panel', async () => {
      createComponent();
      findNavigationRail().vm.$emit('handleTabToggle', 'suggestions');
      await nextTick();
      findContentContainer().vm.$emit('closePanel');
      await nextTick();
      expect(findContentContainer().exists()).toBe(false);
      expect(Cookies.get(aiPanelStateCookie)).toBe(undefined);
    });

    describe('when tabs are toggled twice', () => {
      it.each(['chat', 'suggestions', 'sessions', 'history'])(
        'closes the panel for %s tab',
        async (tabName) => {
          createComponent();
          findNavigationRail().vm.$emit('handleTabToggle', tabName);
          await nextTick();
          findNavigationRail().vm.$emit('handleTabToggle', tabName);
          await nextTick();

          expect(findContentContainer().exists()).toBe(false);
          expect(Cookies.get(aiPanelStateCookie)).toBe(undefined);
        },
      );

      it('keeps the panel open for new chat', async () => {
        createComponent();
        findNavigationRail().vm.$emit('new-chat');
        await nextTick();
        findNavigationRail().vm.$emit('new-chat');
        await nextTick();

        expect(findContentContainer().exists()).toBe(true);
        expect(findContentContainer().props('activeTab')).toEqual({
          title: 'New Chat',
          component: DuoAgenticChat,
          props: {
            mode: 'new',
            isAgenticAvailable: true,
            isEmbedded: true,
            showStudioHeader: true,
          },
        });
      });
    });

    describe('expansion', () => {
      const toggleMaximize = async () => {
        findContentContainer().vm.$emit('toggleMaximize');
        await nextTick();
      };

      it('maximizes', async () => {
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();
        await toggleMaximize();
        expect(findContentContainer().props('isMaximized')).toBe(true);
        expect(findPageLayout().classList.contains('ai-panel-maximized')).toBe(true);
      });

      it('shrinks', async () => {
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();
        await toggleMaximize();
        await toggleMaximize();
        expect(findContentContainer().props('isMaximized')).toBe(false);
        expect(findPageLayout().classList.contains('ai-panel-maximized')).toBe(false);
      });

      it('shrinks on close', async () => {
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();
        await toggleMaximize();
        findContentContainer().vm.$emit('closePanel');
        await nextTick();
        expect(findPageLayout().classList.contains('ai-panel-maximized')).toBe(false);
      });
    });
  });

  describe('Global state watchers', () => {
    describe('duoChatGlobalState.focusChatInput', () => {
      it('focuses the chat input and reset global state', async () => {
        duoChatGlobalState.focusChatInput = false;
        createComponent();

        const focusInputSpy = jest.spyOn(wrapper.vm, 'focusInput');

        duoChatGlobalState.focusChatInput = true;
        await nextTick();

        expect(focusInputSpy).toHaveBeenCalled();
        expect(duoChatGlobalState.focusChatInput).toBe(false);
      });
    });
  });

  describe('panels', () => {
    it.each(['chat', 'suggestions', 'sessions'])(
      'stores %s tab in cookie when toggled',
      async (tabName) => {
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', tabName);
        await nextTick();

        expect(Cookies.get(aiPanelStateCookie)).toBe(tabName);
      },
    );

    describe('router navigation', () => {
      describe('when chat tab is toggled', () => {
        it('navigates to root', async () => {
          createComponent();
          findNavigationRail().vm.$emit('handleTabToggle', 'chat');
          await nextTick();

          expect(mockRouter.push).toHaveBeenCalledWith('/');
        });
      });

      describe('when suggestions tab is toggled', () => {
        it('navigates to root', async () => {
          createComponent();
          findNavigationRail().vm.$emit('handleTabToggle', 'suggestions');
          await nextTick();

          expect(mockRouter.push).toHaveBeenCalledWith('/');
        });
      });

      describe('when history tab is toggled', () => {
        it('navigates to root', async () => {
          createComponent();
          findNavigationRail().vm.$emit('handleTabToggle', 'history');
          await nextTick();

          expect(mockRouter.push).toHaveBeenCalledWith('/');
        });
      });

      describe('when sessions tab is toggled', () => {
        it('navigates to initialRoute', async () => {
          createComponent();
          findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
          await nextTick();

          expect(mockRouter.push).toHaveBeenCalledWith('/agent-sessions/');
        });
      });

      describe('when new chat is triggered', () => {
        it('navigates to root', async () => {
          createComponent();
          findNavigationRail().vm.$emit('new-chat');
          await nextTick();

          expect(mockRouter.push).toHaveBeenCalledWith('/');
        });
      });
    });

    describe('when chat tab is toggled', () => {
      beforeEach(async () => {
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();
      });

      it('calls getContentComponent', () => {
        expect(getContentComponentMock).toHaveBeenCalled();
      });

      it('shows chat panel with correct configuration', () => {
        expect(findContentContainer().props('activeTab')).toEqual({
          title: 'GitLab Duo Agentic Chat',
          component: DuoAgenticChat,
          props: {
            mode: 'active',
            isAgenticAvailable: true,
            isEmbedded: true,
            showStudioHeader: true,
          },
        });
      });
    });

    describe('when suggestions tab is toggled', () => {
      beforeEach(async () => {
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', 'suggestions');
        await nextTick();
      });

      it('does not call getContentComponent', () => {
        expect(getContentComponentMock).not.toHaveBeenCalled();
      });

      it('shows suggestions panel', () => {
        expect(findContentContainer().props('activeTab')).toEqual({
          title: 'Suggestions',
          component: 'Suggestions content placeholder',
        });
      });
    });

    describe('when sessions tab is toggled', () => {
      describe('and on agents platform show route', () => {
        beforeEach(async () => {
          createComponent({
            routeName: AGENTS_PLATFORM_SHOW_ROUTE,
            routeParams: { id: '123' },
          });
          findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
          await nextTick();
        });

        it('formats session title with agent flow name', () => {
          expect(findContentContainer().props('activeTab').title).toBe('Agent session #123');
        });

        it('shows sessions panel with correct component', () => {
          expect(findContentContainer().props('activeTab').component).toBe(AgentSessionsRoot);
        });
      });

      describe('and not on agents platform show route', () => {
        beforeEach(async () => {
          createComponent({
            routeName: 'some_other_route',
          });
          findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
          await nextTick();
        });

        it('uses default Sessions title', () => {
          expect(findContentContainer().props('activeTab').title).toBe('Sessions');
        });

        it('shows sessions panel with correct configuration', () => {
          expect(findContentContainer().props('activeTab')).toEqual({
            title: 'Sessions',
            component: AgentSessionsRoot,
            initialRoute: '/agent-sessions/',
          });
        });
      });
    });
  });

  describe('showBackButton computed property', () => {
    describe('when current tab has initialRoute and route path differs', () => {
      it('shows back button', async () => {
        createComponent({
          routePath: '/agent-sessions/123',
        });
        findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
        await nextTick();
        expect(findContentContainer().props('showBackButton')).toBe(true);
      });
    });

    describe('when current tab has initialRoute but route path matches', () => {
      it('does not show back button', async () => {
        createComponent({
          routePath: '/agent-sessions/',
        });
        findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
        await nextTick();
        expect(findContentContainer().props('showBackButton')).toBe(false);
      });
    });

    describe('when current tab has no initialRoute', () => {
      it('does not show back button', async () => {
        createComponent({
          routePath: '/some-path',
        });
        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();
        expect(findContentContainer().props('showBackButton')).toBe(false);
      });
    });
  });

  describe('handleGoBack method', () => {
    describe('when current tab has initialRoute', () => {
      it('navigates to initial route', async () => {
        createComponent({
          routePath: '/agent-sessions/123',
        });
        findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
        await nextTick();
        findContentContainer().vm.$emit('go-back');
        expect(mockRouter.push).toHaveBeenCalledWith('/agent-sessions/');
      });
    });

    describe('when current tab has no initialRoute', () => {
      it('navigates to root path', async () => {
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();
        findContentContainer().vm.$emit('go-back');
        expect(mockRouter.push).toHaveBeenCalledWith('/');
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
      findNavigationRail().vm.$emit('handleTabToggle', 'chat');
      await nextTick();

      GlBreakpointInstance.isDesktop.mockReturnValue(false);
      triggerResize();
      await nextTick();

      expect(findNavigationRail().props('isExpanded')).toBe(false);
      expect(findContentContainer().exists()).toBe(false);
      expect(duoChatGlobalState.activeTab).toBeUndefined();
    });

    it('does not change panel state when resizing from non-desktop to desktop', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(false);
      createComponent();
      findNavigationRail().vm.$emit('handleTabToggle', 'chat');
      await nextTick();

      GlBreakpointInstance.isDesktop.mockReturnValue(true);
      triggerResize();
      await nextTick();

      expect(findNavigationRail().props('isExpanded')).toBe(true);
      expect(findContentContainer().exists()).toBe(true);
    });

    it('does not change panel state when breakpoint size does not change', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      createComponent();
      findNavigationRail().vm.$emit('handleTabToggle', 'chat');
      await nextTick();

      triggerResize();
      await nextTick();

      expect(findNavigationRail().props('isExpanded')).toBe(true);
      expect(findContentContainer().exists()).toBe(true);
      expect(findContentContainer().props('activeTab').title).toBe('GitLab Duo Agentic Chat');
    });
  });

  describe('props passing', () => {
    it('passes all props to content container', async () => {
      createComponent({
        propsData: {
          projectId: 'gid://gitlab/Project/999',
          namespaceId: 'gid://gitlab/Group/888',
          rootNamespaceId: 'gid://gitlab/Group/777',
          resourceId: 'gid://gitlab/Resource/666',
          metadata: '{"test":"data"}',
          userModelSelectionEnabled: true,
        },
      });
      findNavigationRail().vm.$emit('handleTabToggle', 'chat');
      await nextTick();
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

  describe('router navigation for tabs with initialRoute', () => {
    it('navigates to initialRoute when activating sessions tab for the first time', async () => {
      createComponent();

      findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
      await nextTick();

      expect(mockRouter.push).toHaveBeenCalledWith('/agent-sessions/');
    });

    it('does not navigate when activating chat tabs without initialRoute', async () => {
      createComponent();

      findNavigationRail().vm.$emit('handleTabToggle', 'chat');
      await nextTick();

      expect(mockRouter.push).toHaveBeenCalledWith('/');
    });

    it('restores the previous route when switching back to a tab', async () => {
      duoChatGlobalState.lastRoutePerTab = { sessions: '/agent-sessions/123' };
      createComponent({
        mountFn: mountExtended,
        routePath: '/agent-sessions/123',
        routeName: AGENTS_PLATFORM_SHOW_ROUTE,
        routeParams: { id: '123' },
      });

      findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
      await nextTick();
      expect(findContentContainer().props('activeTab').title).toBe('Agent session #123');

      findNavigationRail().vm.$emit('handleTabToggle', 'chat');
      await nextTick();

      findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
      await nextTick();
      expect(mockRouter.push).toHaveBeenCalledWith('/agent-sessions/123');
    });

    it('navigates to stored route when returning to a tab with initialRoute', async () => {
      duoChatGlobalState.lastRoutePerTab = { sessions: '/agent-sessions/123' };
      createComponent({ routePath: '/agent-sessions/123' });

      findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
      await nextTick();
      findNavigationRail().vm.$emit('handleTabToggle', 'chat');
      await nextTick();

      mockRouter.push.mockClear();

      findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
      await nextTick();

      expect(mockRouter.push).toHaveBeenCalledWith('/agent-sessions/123');
    });

    it('restores the initialRoute when panel opens from cookie', async () => {
      Cookies.set(aiPanelStateCookie, 'sessions');
      createComponent({
        mountFn: mountExtended,
        routePath: '/agent-sessions/456',
        routeName: AGENTS_PLATFORM_SHOW_ROUTE,
        routeParams: { id: '456' },
      });
      await nextTick();

      expect(findContentContainer().exists()).toBe(true);
      expect(findContentContainer().props('activeTab').title).toBe('Agent session #456');
      expect(findContentContainer().props('activeTab').component).toBe(AgentSessionsRoot);
    });

    it('navigates to updated route when switching back after route change within a tab', async () => {
      createComponent({
        mountFn: mountExtended,
        routePath: '/agent-sessions/',
        routeName: 'some_route',
      });
      findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
      await nextTick();
      expect(findContentContainer().props('activeTab').title).toBe('Sessions');

      // Simulate route guard tracking the navigation to a specific session
      duoChatGlobalState.lastRoutePerTab.sessions = '/agent-sessions/789';

      findNavigationRail().vm.$emit('handleTabToggle', 'chat');
      await nextTick();
      mockRouter.push.mockClear();

      findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
      await nextTick();

      expect(mockRouter.push).toHaveBeenCalledWith('/agent-sessions/789');
    });

    it('preserves routes for multiple tabs independently', async () => {
      // Simulate route guard having tracked routes for multiple tabs
      duoChatGlobalState.lastRoutePerTab = {
        sessions: '/agent-sessions/123',
        chat: '/',
      };

      createComponent({ routePath: '/agent-sessions/111' });

      findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
      await nextTick();

      findNavigationRail().vm.$emit('handleTabToggle', 'chat');
      await nextTick();

      mockRouter.push.mockClear();
      findNavigationRail().vm.$emit('handleTabToggle', 'sessions');
      await nextTick();

      expect(mockRouter.push).toHaveBeenCalledWith('/agent-sessions/123');
      expect(duoChatGlobalState.lastRoutePerTab.sessions).toBe('/agent-sessions/123');
      expect(duoChatGlobalState.lastRoutePerTab.chat).toBe('/');
    });
  });

  describe('onSwitchToActiveTab', () => {
    it('switches to specified tab when event is emitted from content container', async () => {
      createComponent();
      findNavigationRail().vm.$emit('handleTabToggle', 'history');
      await nextTick();

      findContentContainer().vm.$emit('switch-to-active-tab', 'chat');
      await nextTick();

      expect(findContentContainer().props('activeTab')).toEqual({
        title: 'GitLab Duo Agentic Chat',
        component: DuoAgenticChat,
        props: {
          mode: 'active',
          isAgenticAvailable: true,
          isEmbedded: true,
          showStudioHeader: true,
        },
      });
      expect(Cookies.get(aiPanelStateCookie)).toBe('chat');
      expect(duoChatGlobalState.activeTab).toBe('chat');
    });

    it('updates active tab without triggering navigation', async () => {
      createComponent();
      findNavigationRail().vm.$emit('handleTabToggle', 'history');
      await nextTick();
      mockRouter.push.mockClear();

      findContentContainer().vm.$emit('switch-to-active-tab', 'sessions');
      await nextTick();

      expect(mockRouter.push).not.toHaveBeenCalled();
      expect(duoChatGlobalState.activeTab).toBe('sessions');
      expect(Cookies.get(aiPanelStateCookie)).toBe('sessions');
    });
  });

  describe('tab configuration', () => {
    describe('when chat tab is selected', () => {
      beforeEach(async () => {
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();
      });
      it('returns chat tab with mode "active"', () => {
        expect(findContentContainer().props('activeTab')).toEqual({
          title: 'GitLab Duo Agentic Chat',
          component: DuoAgenticChat,
          props: {
            mode: 'active',
            isAgenticAvailable: true,
            isEmbedded: true,
            showStudioHeader: true,
          },
        });
      });
    });

    describe('when the new chat tab becomes active', () => {
      beforeEach(async () => {
        createComponent();
        findNavigationRail().vm.$emit('new-chat');
        await nextTick();
      });

      it('calls getContentComponent', () => {
        expect(getContentComponentMock).toHaveBeenCalled();
      });

      it('returns new chat tab with mode "new"', () => {
        expect(findContentContainer().props('activeTab')).toEqual({
          title: 'New Chat',
          component: DuoAgenticChat,
          props: {
            mode: 'new',
            isAgenticAvailable: true,
            isEmbedded: true,
            showStudioHeader: true,
          },
        });
      });
    });

    describe('when history becomes active', () => {
      beforeEach(async () => {
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', 'history');
        await nextTick();
      });
      it('returns history tab with mode "history"', () => {
        expect(findContentContainer().props('activeTab')).toEqual({
          title: 'History',
          component: DuoAgenticChat,
          props: {
            mode: 'history',
            isAgenticAvailable: true,
            isEmbedded: true,
            showStudioHeader: true,
          },
        });
      });
    });
  });

  describe('chat mode switching', () => {
    describe('component switching based on chat mode', () => {
      it('renders agentic chat component when in agentic mode', async () => {
        duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();

        expect(findContentContainer().props('activeTab')).toEqual({
          title: 'GitLab Duo Agentic Chat',
          component: DuoAgenticChat,
          props: {
            mode: 'active',
            isAgenticAvailable: true,
            isEmbedded: true,
            showStudioHeader: true,
          },
        });
      });

      it('renders classic chat component when in classic mode', async () => {
        duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
        createComponent();

        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();

        expect(findContentContainer().props('activeTab')).toEqual({
          title: 'GitLab Duo Chat',
          component: DuoChat,
          props: {
            mode: 'chat',
            isAgenticAvailable: true,
            isEmbedded: true,
            showStudioHeader: true,
          },
        });
      });

      it('switches component when chat mode changes from agentic to classic', async () => {
        duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
        createComponent();
        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();

        expect(findContentContainer().props('activeTab').component).toBe(DuoAgenticChat);
        expect(findContentContainer().props('activeTab').title).toBe('GitLab Duo Agentic Chat');

        duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
        await nextTick();

        expect(findContentContainer().props('activeTab').component).toBe(DuoChat);
        expect(findContentContainer().props('activeTab').title).toBe('GitLab Duo Chat');
      });

      it('applies classic mode to all chat tabs (active, new, history)', async () => {
        duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
        createComponent();

        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();
        expect(findContentContainer().props('activeTab').component).toBe(DuoChat);

        findNavigationRail().vm.$emit('new-chat');
        await nextTick();
        expect(findContentContainer().props('activeTab').component).toBe(DuoChat);
        expect(findContentContainer().props('activeTab').title).toBe('New Chat');

        findNavigationRail().vm.$emit('handleTabToggle', 'history');
        await nextTick();
        expect(findContentContainer().props('activeTab').component).toBe(DuoChat);
        expect(findContentContainer().props('activeTab').title).toBe('History');
      });

      it('applies agentic mode to all chat tabs (active, new, history)', async () => {
        duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
        createComponent();

        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();
        expect(findContentContainer().props('activeTab').component).toBe(DuoAgenticChat);

        findNavigationRail().vm.$emit('new-chat');
        await nextTick();
        expect(findContentContainer().props('activeTab').component).toBe(DuoAgenticChat);
        expect(findContentContainer().props('activeTab').title).toBe('New Chat');

        findNavigationRail().vm.$emit('handleTabToggle', 'history');
        await nextTick();
        expect(findContentContainer().props('activeTab').component).toBe(DuoAgenticChat);
        expect(findContentContainer().props('activeTab').title).toBe('History');
      });
    });

    describe('activeTab reactivity with global state', () => {
      it('opens panel when global state activeTab changes externally', async () => {
        createComponent();
        expect(findContentContainer().exists()).toBe(false);

        // Simulate external trigger (e.g., from sendDuoChatCommand)
        duoChatGlobalState.activeTab = 'chat';
        await nextTick();

        expect(findContentContainer().exists()).toBe(true);
        expect(findContentContainer().props('activeTab').component).toBe(DuoAgenticChat);
      });

      it('clears global state and cookie when panel is closed', async () => {
        createComponent();

        findNavigationRail().vm.$emit('handleTabToggle', 'chat');
        await nextTick();
        expect(duoChatGlobalState.activeTab).toBe('chat');

        findContentContainer().vm.$emit('closePanel');
        await nextTick();

        expect(duoChatGlobalState.activeTab).toBeUndefined();
        expect(Cookies.get(aiPanelStateCookie)).toBeUndefined();
        expect(findContentContainer().exists()).toBe(false);
      });
    });
  });

  describe('when chat is disabled', () => {
    describe('with chatDisabledReason prop set', () => {
      it('passes chatDisabledReason and IDs to navigation rail', () => {
        createComponent({
          propsData: {
            chatDisabledReason: 'project',
            projectId: 'gid://gitlab/Project/123',
            namespaceId: 'gid://gitlab/Group/456',
          },
        });
        expect(findNavigationRail().props()).toMatchObject({
          chatDisabledReason: 'project',
          projectId: 'gid://gitlab/Project/123',
          namespaceId: 'gid://gitlab/Group/456',
        });
      });

      it('prevents opening chat tab on mount', async () => {
        Cookies.set(aiPanelStateCookie, 'chat');
        createComponent({ propsData: { chatDisabledReason: 'project' } });
        await nextTick();

        expect(findContentContainer().exists()).toBe(false);
        expect(duoChatGlobalState.activeTab).toBeUndefined();
      });
    });
  });
});
