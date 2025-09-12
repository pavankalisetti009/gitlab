import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import AIPanel from 'ee/ai/components/ai_panel.vue';
import AiContentContainer from 'ee/ai/components/content_container.vue';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import AgentSessions from 'ee/ai/duo_agents_platform/duo_agents_platform_app.vue';
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
  } = {}) => {
    mockRouter = {
      push: jest.fn(),
    };

    wrapper = shallowMountExtended(AIPanel, {
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

  describe('when sessions tab is active', () => {
    it('returns sessions tab configuration with AgentSessions component', () => {
      createComponent({ activeTab: 'sessions' });

      expect(findContentContainer().props('activeTab')).toEqual({
        title: 'Sessions',
        component: AgentSessions,
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
});
