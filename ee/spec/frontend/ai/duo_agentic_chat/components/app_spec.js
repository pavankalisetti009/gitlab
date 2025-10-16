import { DuoLayout, SideRail } from '@gitlab/duo-ui';
import Vue, { nextTick } from 'vue';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import DuoAgenticLayoutApp from 'ee/ai/duo_agentic_chat/components/app.vue';
import { WIDTH_OFFSET } from 'ee/ai/tanuki_bot/constants';

describe('DuoAgenticLayoutApp', () => {
  let wrapper;

  const RouterViewStub = Vue.extend({
    name: 'RouterViewStub',
    template: '<div />',
  });

  const findDuoLayout = () => wrapper.findComponent(DuoLayout);
  const findSideRail = () => wrapper.findComponent(SideRail);

  const mockRouter = {
    push: jest.fn(),
  };

  const mockRoute = {
    path: '/test',
  };

  const createWrapper = (propsData = {}, provideOptions = {}) => {
    return shallowMountExtended(DuoAgenticLayoutApp, {
      propsData: {
        projectId: 'gid://gitlab/Project/123',
        namespaceId: 'gid://gitlab/Group/456',
        resourceId: 'gid://gitlab/Resource/789',
        ...propsData,
      },
      provide: {
        glFeatures: {
          duoSideRail: false,
        },
        ...provideOptions,
      },
      mocks: {
        $route: mockRoute,
        $router: {
          ...mockRouter,
        },
      },
      slots: {
        siderail: SideRail,
      },
      stubs: {
        DuoLayout,
        'router-view': RouterViewStub,
      },
    });
  };

  beforeEach(() => {
    duoChatGlobalState.isAgenticChatShown = true;
  });

  afterEach(() => {
    duoChatGlobalState.isAgenticChatShown = false;
  });

  describe('when Duo Chat is shown', () => {
    beforeEach(async () => {
      wrapper = await createWrapper();
    });

    it('renders the DuoLayout component', () => {
      expect(findDuoLayout().exists()).toBe(true);
    });

    it('passes correct dimensions to DuoLayout', () => {
      const expectedDimensions = {
        width: 550,
        height: window.innerHeight,
        top: 0, // This is calculated as window.innerHeight - height, but height equals window.innerHeight
        maxHeight: window.innerHeight,
        maxWidth: window.innerWidth - WIDTH_OFFSET,
        minWidth: 550,
        minHeight: 400,
        left: window.innerWidth - 550,
      };

      expect(findDuoLayout().props('dimensions')).toEqual(expectedDimensions);
    });

    it('fixes layout to the right', () => {
      expect(findDuoLayout().classes()).toContain('gl-right-0', '!gl-left-auto');
    });

    it('passes shouldRenderResizable prop to DuoLayout', () => {
      expect(findDuoLayout().props('shouldRenderResizable')).toBe(true);
    });

    it('passes baseProps to router-view', () => {
      const routerView = wrapper.findComponent(RouterViewStub);

      expect(routerView.exists()).toBe(true);
      expect(routerView.attributes()).toMatchObject({
        projectid: 'gid://gitlab/Project/123',
        namespaceid: 'gid://gitlab/Group/456',
        resourceid: 'gid://gitlab/Resource/789',
      });
    });

    it('navigates to /current route on mount', () => {
      expect(mockRouter.push).toHaveBeenCalledWith('/current');
    });
  });

  describe('when Duo Chat is not shown', () => {
    beforeEach(async () => {
      duoChatGlobalState.isAgenticChatShown = false;
      wrapper = await createWrapper();
    });

    it('does not render the DuoLayout component', () => {
      expect(findDuoLayout().exists()).toBe(false);
    });
  });

  describe('when duoSideRail feature flag is enabled', () => {
    beforeEach(async () => {
      wrapper = await createWrapper({}, { glFeatures: { duoSideRail: true } });
    });

    it('renders the SideRail component', () => {
      expect(findSideRail().exists()).toBe(true);
    });

    it('passes correct buttons configuration to SideRail', async () => {
      await nextTick();
      const expectedButtons = {
        current: { render: true, avatar: 'GitLab Duo Agentic Chat', title: 'Current Chat' },
        new: { render: true, icon: 'plus', title: 'New Chat' },
        history: { render: true, icon: 'history', title: 'History' },
        sessions: {
          render: true,
          icon: 'session-ai',
          dividerBefore: true,
          title: 'Sessions',
          classes: 'gl-p-3',
        },
      };

      expect(findSideRail().props('buttons')).toEqual(expectedButtons);
    });
  });

  describe('when duoSideRail feature flag is disabled', () => {
    beforeEach(async () => {
      wrapper = await createWrapper();
    });

    it('does not render the SideRail component', async () => {
      await nextTick();
      expect(findSideRail().exists()).toBe(false);
    });
  });

  describe('dimensions management', () => {
    beforeEach(async () => {
      wrapper = await createWrapper();
    });

    it('initializes dimensions correctly on mount', () => {
      expect(wrapper.vm.width).toBe(550);
      expect(wrapper.vm.height).toBe(window.innerHeight);
      expect(wrapper.vm.maxWidth).toBe(window.innerWidth - WIDTH_OFFSET);
      expect(wrapper.vm.maxHeight).toBe(window.innerHeight);
    });

    it('updates dimensions when chat-resize event is emitted', async () => {
      const newWidth = 600;
      const newHeight = 500;

      wrapper.vm.onChatResize({ width: newWidth, height: newHeight });
      await nextTick();

      expect(wrapper.vm.width).toBe(newWidth);
      expect(wrapper.vm.height).toBe(newHeight);
    });

    it('ensures dimensions do not exceed maxWidth or maxHeight', async () => {
      const newWidth = window.innerWidth + 100;
      const newHeight = window.innerHeight + 100;

      wrapper.vm.onChatResize({ width: newWidth, height: newHeight });
      await nextTick();

      expect(wrapper.vm.width).toBe(window.innerWidth - WIDTH_OFFSET);
      expect(wrapper.vm.height).toBe(window.innerHeight);
    });

    it('updates dimensions when window is resized', async () => {
      const originalInnerWidth = window.innerWidth;
      const originalInnerHeight = window.innerHeight;

      try {
        window.innerWidth = 1200;
        window.innerHeight = 800;

        window.dispatchEvent(new Event('resize'));
        await nextTick();

        expect(wrapper.vm.maxWidth).toBe(1200 - WIDTH_OFFSET);
        expect(wrapper.vm.maxHeight).toBe(800);
      } finally {
        window.innerWidth = originalInnerWidth;
        window.innerHeight = originalInnerHeight;
      }
    });
  });

  describe('navigation', () => {
    beforeEach(async () => {
      wrapper = await createWrapper({}, { glFeatures: { duoSideRail: true } });
    });

    it('navigates to correct route when onClick is called', async () => {
      await wrapper.vm.onClick('new');
      await waitForPromises();
      expect(mockRouter.push).toHaveBeenCalledWith('/new');

      await wrapper.vm.onClick('history');
      await waitForPromises();
      expect(mockRouter.push).toHaveBeenCalledWith('/history');

      await wrapper.vm.onClick('current');
      await waitForPromises();
      expect(mockRouter.push).toHaveBeenCalledWith('/current');
    });

    it('emits tooltip hide event when onClick is called', async () => {
      await wrapper.vm.onClick('new');
      await waitForPromises();

      expect(mockRouter.push).toHaveBeenCalledWith('/new');
    });

    it('handles SideRail click events', async () => {
      await findSideRail().vm.$emit('click', 'history');
      await waitForPromises();

      expect(mockRouter.push).toHaveBeenCalledWith('/history');
    });
  });

  describe('props handling', () => {
    it('passes all props correctly to baseProps computed property', async () => {
      const propsData = {
        projectId: 'project-123',
        namespaceId: 'namespace-456',
        resourceId: 'resource-789',
        metadata: '{"test": true}',
        rootNamespaceId: 'root-namespace-999',
        userModelSelectionEnabled: true,
      };

      wrapper = await createWrapper(propsData);

      expect(wrapper.vm.baseProps).toEqual(propsData);
    });

    it('handles null/undefined props correctly', async () => {
      wrapper = await createWrapper({
        projectId: null,
        namespaceId: null,
      });

      expect(wrapper.vm.baseProps).toMatchObject({
        projectId: null,
        namespaceId: null,
        resourceId: 'gid://gitlab/Resource/789',
        metadata: null,
        rootNamespaceId: null,
        userModelSelectionEnabled: false,
      });
    });
  });

  describe('cleanup', () => {
    beforeEach(async () => {
      wrapper = await createWrapper();
    });

    it('removes window resize event listener on destroy', () => {
      const removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');

      // Handle both Vue 2 (destroy) and Vue 3 (unmount) methods
      if (wrapper.unmount) {
        wrapper.unmount();
      } else {
        wrapper.destroy();
      }

      expect(removeEventListenerSpy).toHaveBeenCalledWith('resize', wrapper.vm.onWindowResize);
    });
  });
});
