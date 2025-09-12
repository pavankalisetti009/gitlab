import { shallowMount } from '@vue/test-utils';

import PageHeading from '~/vue_shared/components/page_heading.vue';
import DuoAgentsPlatformNew from 'ee/ai/duo_agents_platform/pages/new/duo_agents_platform_new.vue';
import RunAgentFlowForm from 'ee/ai/duo_agents_platform/components/common/run_agent_flow_form.vue';
import { AGENTFLOW_TYPE_JENKINS_TO_CI } from 'ee/ai/duo_agents_platform/constants';

describe('DuoAgentsPlatformNew', () => {
  let wrapper;

  const mockRouter = {
    push: jest.fn(),
  };
  const defaultProvide = {
    projectPath: 'group/project',
  };

  const createWrapper = (props = {}, provide = {}) => {
    wrapper = shallowMount(DuoAgentsPlatformNew, {
      propsData: {
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      mocks: {
        $router: mockRouter,
      },
    });
  };

  const findRunAgentFlowForm = () => wrapper.findComponent(RunAgentFlowForm);
  const findPageHeading = () => wrapper.findComponent(PageHeading);

  beforeEach(() => {
    createWrapper();
  });

  it('renders the page heading', () => {
    expect(findPageHeading().exists()).toBe(true);
    expect(findPageHeading().props('heading')).toBe('Start an agent session');
  });

  it('passes the right props to the RunAgentFlowForm component', () => {
    expect(findRunAgentFlowForm().props()).toEqual({
      defaultAgentFlowType: AGENTFLOW_TYPE_JENKINS_TO_CI,
      projectPath: defaultProvide.projectPath,
      flows: expect.any(Array),
    });
  });

  describe('events', () => {
    it('handles the agent-flow-started event', async () => {
      const data = { id: 123 };

      await findRunAgentFlowForm().vm.$emit('agent-flow-started', data);

      expect(mockRouter.push).toHaveBeenCalledWith({
        name: 'agents_platform_show_route',
        params: { id: 123 },
      });
    });
  });
});
