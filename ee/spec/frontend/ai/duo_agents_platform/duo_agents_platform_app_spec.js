import { shallowMount } from '@vue/test-utils';
import DuoAgentsPlatformApp from 'ee/ai/duo_agents_platform/duo_agents_platform_app.vue';

describe('DuoAgentsPlatformApp', () => {
  let mockRoute;

  let wrapper;

  const createWrapper = (props = {}) => {
    mockRoute = {
      path: '/',
      name: 'agents_platform_index_page',
    };

    return shallowMount(DuoAgentsPlatformApp, {
      propsData: props,
      mocks: {
        $route: mockRoute,
      },
      stubs: {
        RouterView: true,
      },
    });
  };

  const findAppContainer = () => wrapper.find('#agents-platform-app');

  describe('when component is mounted', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('renders the app container', () => {
      expect(findAppContainer().exists()).toBe(true);
    });

    it('renders the router-view component', () => {
      expect(wrapper.html()).toContain('routerview');
    });
  });
});
