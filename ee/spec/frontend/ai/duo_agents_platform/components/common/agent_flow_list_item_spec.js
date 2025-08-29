import { GlLink } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import AgentFlowListItem from 'ee/ai/duo_agents_platform/components/common/agent_flow_list_item.vue';
import AgentStatusIcon from 'ee/ai/duo_agents_platform/components/common/agent_status_icon.vue';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { getTimeago } from '~/lib/utils/datetime/timeago_utility';

jest.mock('~/lib/utils/datetime/timeago_utility');

describe('AgentFlowListItem', () => {
  let wrapper;

  const mockTimeago = {
    format: jest.fn(),
  };

  const mockItem = {
    id: 'gid://gitlab/DuoWorkflow::Workflow/1',
    status: 'FINISHED',
    humanStatus: 'finished',
    updatedAt: '2024-01-01T00:00:00Z',
    workflowDefinition: 'software_development',
  };

  const createWrapper = (props = {}) => {
    wrapper = mount(AgentFlowListItem, {
      propsData: {
        item: mockItem,
        ...props,
      },
      stubs: {
        AgentStatusIcon,
        GlLink,
      },
    });
  };

  const findLink = () => wrapper.findComponent(GlLink);
  const findStatusIcon = () => wrapper.findComponent(AgentStatusIcon);

  describe('when component is mounted', () => {
    beforeEach(() => {
      getTimeago.mockReturnValue(mockTimeago);
      mockTimeago.format.mockReturnValue('2 days ago');
      createWrapper();
    });

    it('renders as a list item', () => {
      expect(wrapper.find('li').exists()).toBe(true);
    });

    it('renders and sets the correct route for the link', () => {
      expect(findLink().exists()).toBe(true);
      expect(findLink().props('to')).toEqual({
        name: AGENTS_PLATFORM_SHOW_ROUTE,
        params: { id: 1 },
      });
    });

    it('renders the status icon', () => {
      expect(findStatusIcon().exists()).toBe(true);
    });

    it('displays the formatted status', () => {
      expect(wrapper.text()).toContain('Finished');
    });

    it('displays the formatted agent name', () => {
      expect(wrapper.text()).toContain('Software development #1');
    });

    it('displays the formatted updated time', () => {
      expect(wrapper.text()).toContain('2 days ago');
    });
  });
});
