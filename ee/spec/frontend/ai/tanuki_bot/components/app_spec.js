import { DuoLayout, SideRail } from '@gitlab/duo-ui';
import { GlButton } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import DuoClassicLayoutApp from 'ee/ai/tanuki_bot/components/app.vue';
import { WIDTH_OFFSET } from 'ee/ai/tanuki_bot/constants';

describe('DuoAgenticClassicApp', () => {
  let wrapper;

  const RouterViewStub = Vue.extend({
    name: 'RouterViewStub',
    template: '<div />',
  });

  const findDuoLayout = () => wrapper.findComponent(DuoLayout);
  const findAllSiderailButtons = () => wrapper.findAllComponents(GlButton);
  const findSiderailNewButton = () =>
    findAllSiderailButtons().wrappers.filter((w) => w.attributes('icon') === 'plus');
  const findSiderailHistoryButton = () =>
    findAllSiderailButtons().wrappers.filter((w) => w.attributes('icon') === 'history');

  const mockRouter = {
    push: jest.fn(),
  };

  const mockRoute = {
    path: '/test',
  };

  const createWrapper = (propsData = {}, provideOptions = {}) => {
    return shallowMountExtended(DuoClassicLayoutApp, {
      propsData: {
        userId: 'gid://gitlab/User/1',
        projectId: 'gid://gitlab/Project/123',
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
      stubs: {
        DuoLayout,
        SideRail,
        'router-view': RouterViewStub,
      },
    });
  };

  beforeEach(() => {
    duoChatGlobalState.isShown = true;
  });

  afterEach(() => {
    duoChatGlobalState.isShown = false;
  });

  describe('when Duo Chat drawer is shown', () => {
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
      const classes = findDuoLayout().classes();
      expect(classes).toContain('gl-right-0');
      expect(classes).toContain('!gl-left-auto');
    });

    it('passes shouldRenderResizable prop to DuoLayout', () => {
      expect(findDuoLayout().props('shouldRenderResizable')).toBe(true);
    });

    it('passes baseProps to router-view', () => {
      const routerView = wrapper.findComponent(RouterViewStub);

      expect(routerView.exists()).toBe(true);
      expect(routerView.attributes()).toMatchObject({
        userid: 'gid://gitlab/User/1',
        projectid: 'gid://gitlab/Project/123',
        resourceid: 'gid://gitlab/Resource/789',
      });
    });

    it('navigates to /new route on mount', () => {
      expect(mockRouter.push).toHaveBeenCalledWith('/new');
    });
  });

  describe('when Duo Chat drawer is not shown', () => {
    beforeEach(async () => {
      duoChatGlobalState.isShown = false;
      wrapper = await createWrapper();
    });

    it('does not render the DuoLayout component', () => {
      expect(findDuoLayout().exists()).toBe(false);
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

      const routerView = wrapper.findComponent(RouterViewStub);
      routerView.vm.$emit('chat-resize', { width: newWidth, height: newHeight });

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
      mockRoute.path = '/test';
      mockRouter.push.mockClear();

      await findSiderailNewButton().at(0).vm.$emit('click');
      await waitForPromises();
      expect(mockRouter.push).toHaveBeenCalledWith('/new');

      mockRoute.path = '/new';
      mockRouter.push.mockClear();

      await findSiderailHistoryButton().at(0).vm.$emit('click');
      await waitForPromises();
      expect(mockRouter.push).toHaveBeenCalledWith('/history');
    });

    it('handles SideRail click events', async () => {
      mockRoute.path = '/test';
      mockRouter.push.mockClear();

      await findSiderailHistoryButton().at(0).vm.$emit('click');
      await waitForPromises();

      expect(mockRouter.push).toHaveBeenCalledWith('/history');
    });
  });

  describe('cleanup', () => {
    beforeEach(async () => {
      wrapper = await createWrapper();
    });

    it('removes window resize event listener on destroy', () => {
      const removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');

      wrapper.destroy();

      expect(removeEventListenerSpy).toHaveBeenCalledWith('resize', wrapper.vm.onWindowResize);
    });
  });
});
