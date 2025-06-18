import { shallowMount } from '@vue/test-utils';
import DuoAgentsPlatformShow from 'ee/ai/duo_agents_platform/pages/show/duo_agents_platform_show.vue';

describe('DuoAgentsPlatformShow', () => {
  let wrapper;
  let mockRoute;

  const createWrapper = (props = {}) => {
    mockRoute = {
      params: {
        id: 'gid://gitlab/DuoWorkflow::Workflow/1',
      },
    };

    return shallowMount(DuoAgentsPlatformShow, {
      propsData: props,
      mocks: {
        $route: mockRoute,
      },
    });
  };

  const findIdDisplay = () => wrapper.find('p');

  describe('when component is mounted', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('displays the workflow id from route params', () => {
      expect(findIdDisplay().text()).toBe('gid://gitlab/DuoWorkflow::Workflow/1');
    });
  });
});
