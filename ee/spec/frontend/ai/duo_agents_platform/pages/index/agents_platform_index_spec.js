import { shallowMount } from '@vue/test-utils';
import AgentsPlatformIndex from 'ee/ai/duo_agents_platform/pages/index/agents_platform_index.vue';

// Finders
const findHeading = (wrapper) => wrapper.find('h1');

describe('AgentsPlatformIndex', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return shallowMount(AgentsPlatformIndex, {
      propsData: props,
    });
  };

  describe('when component is mounted', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('renders the correct heading text', () => {
      expect(findHeading(wrapper).text()).toBe('Agents Platform Index');
    });
  });
});
