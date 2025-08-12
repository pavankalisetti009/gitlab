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
        ...props,
      },
    });
  };

  const findListItems = () => wrapper.findAll('li');
  const findSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({
        isLoading: true,
        status: 'RUNNING',
        agentFlowDefinition: 'software_development',
      });
    });

    it('renders UI copy as usual', () => {
      expect(findListItems()).toHaveLength(3);
    });

    it('displays the skeleton loaders', () => {
      expect(findSkeletonLoaders()).toHaveLength(3);
    });

    it('does not display placeholder N/A values', () => {
      expect(wrapper.text()).not.toContain('N/A');
    });
  });

  describe('info data', () => {
    it.each`
      status       | agentFlowDefinition       | executorUrl                                               | expectedStatus | expectedType              | expectedID
      ${'STOPPED'} | ${'software_development'} | ${'https://gitlab.com/gitlab-org/gitlab/-/pipelines/123'} | ${'STOPPED'}   | ${'software_development'} | ${'123'}
      ${'STARTED'} | ${'testing'}              | ${'https://gitlab.com/gitlab-org/gitlab/-/pipelines/4'}   | ${'STARTED'}   | ${'testing'}              | ${'4'}
      ${''}        | ${'something_else'}       | ${'https://gitlab.com/gitlab-org/gitlab/-/pipelines/'}    | ${'N/A'}       | ${'something_else'}       | ${'N/A'}
      ${'RUNNING'} | ${''}                     | ${'https://gitlab.com/gitlab-org/gitlab/-/pipelines/123'} | ${'RUNNING'}   | ${'N/A'}                  | ${'123'}
      ${''}        | ${''}                     | ${'https://gitlab.com/gitlab-org/gitlab/-/pipelines/123'} | ${'N/A'}       | ${'N/A'}                  | ${'123'}
    `(
      'renders expected values when status is $status and definition is `$workflowDefinition`',
      ({ status, agentFlowDefinition, executorUrl, expectedStatus, expectedType, expectedID }) => {
        createComponent({ status, agentFlowDefinition, executorUrl });

        expect(findListItems().at(0).text()).toContain(`Status: ${expectedStatus}`);
        expect(findListItems().at(1).text()).toContain(`Type: ${expectedType}`);
        expect(findListItems().at(2).text()).toContain(`Executor ID: ${expectedID}`);
      },
    );
  });
});
