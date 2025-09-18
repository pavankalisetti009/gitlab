import { GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
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
    project: {
      id: 'gid://gitlab/Project/1',
      name: 'Test Project',
      namespace: {
        id: 'gid://gitlab/Group/1',
        name: 'gitlab-org',
      },
    },
  };

  const findLink = () => wrapper.findComponent(GlLink);
  const findStatusIcon = () => wrapper.findComponent(AgentStatusIcon);

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(AgentFlowListItem, {
      propsData: {
        item: mockItem,
        ...props,
      },
    });
  };

  describe('when component is mounted', () => {
    describe('when showProjectInfo is false', () => {
      beforeEach(() => {
        getTimeago.mockReturnValue(mockTimeago);
        mockTimeago.format.mockReturnValue('2 days ago');
        createWrapper({ showProjectInfo: false });
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

      it('displays status and updated time inline with separator', () => {
        const text = wrapper.text();
        expect(text).toContain('Finished · 2 days ago');
      });

      it('does not display project information', () => {
        expect(wrapper.text()).not.toContain('Test Project');
      });
    });

    describe('when showProjectInfo is true', () => {
      beforeEach(() => {
        getTimeago.mockReturnValue(mockTimeago);
        mockTimeago.format.mockReturnValue('2 days ago');
        createWrapper({ showProjectInfo: true });
      });

      it('displays project name', () => {
        expect(wrapper.text()).toContain('Test Project');
      });

      it('displays all other information as well', () => {
        expect(wrapper.text()).toContain('Finished');
        expect(wrapper.text()).toContain('Software development #1');
        expect(wrapper.text()).toContain('2 days ago');
      });

      it('displays status and updated time inline with separator', () => {
        const text = wrapper.text();
        expect(text).toContain('Finished · 2 days ago');
      });
    });

    describe('when showProjectInfo is not provided', () => {
      beforeEach(() => {
        getTimeago.mockReturnValue(mockTimeago);
        mockTimeago.format.mockReturnValue('2 days ago');
        createWrapper();
      });

      it('defaults to not showing project information', () => {
        expect(wrapper.text()).not.toContain('Test Project');
      });
    });
  });
});
