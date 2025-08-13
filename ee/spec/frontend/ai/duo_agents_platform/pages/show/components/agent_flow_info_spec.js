import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentFlowInfo from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_info.vue';

describe('AgentFlowInfo', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AgentFlowInfo, {
      propsData: {
        isLoading: false,
        status: 'RUNNING',
        agentFlowDefinition: 'software_development',
        executorUrl: 'https://gitlab.com/gitlab-org/gitlab/-/pipelines/123',
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
        ...props,
      },
      mocks: {
        $route: {
          params: {
            id: '4545',
          },
        },
      },
    });
  };

  const findListItems = () => wrapper.findAll('li');
  const findSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({
        isLoading: true,
      });
    });

    it('renders UI copy as usual', () => {
      expect(findListItems()).toHaveLength(7);
    });

    it('displays the skeleton loaders', () => {
      expect(findSkeletonLoaders()).toHaveLength(7);
    });

    it('does not display placeholder N/A values', () => {
      expect(wrapper.text()).not.toContain('N/A');
    });
  });

  describe('info data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders all expected data', () => {
      expect(findListItems().at(0).text()).toContain('RUNNING');
      expect(findListItems().at(1).text()).toContain('Jan 01, 2023 - 00:00:00');
      expect(findListItems().at(2).text()).toContain('Jan 01, 2024 - 00:00:00');
      expect(findListItems().at(3).text()).toContain('Flow');
      expect(findListItems().at(4).text()).toContain('software_development');
      expect(findListItems().at(5).text()).toContain('4545');
    });
  });
});
