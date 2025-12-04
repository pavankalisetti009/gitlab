import { GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentFlowListItem from 'ee/ai/duo_agents_platform/components/common/agent_flow_list_item.vue';
import AgentStatusIcon from 'ee/ai/duo_agents_platform/components/common/agent_status_icon.vue';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { getTimeago } from '~/lib/utils/datetime/timeago_utility';

jest.mock('~/lib/utils/datetime/timeago_utility');

describe('AgentFlowListItem', () => {
  let wrapper;
  let mockRouter;

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
      webUrl: 'https://gitlab.com/gitlab-org/test-project',
      namespace: {
        id: 'gid://gitlab/Group/1',
        name: 'gitlab-org',
      },
    },
  };

  const findLink = () => wrapper.findComponent(GlLink);
  const findStatusIcon = () => wrapper.findComponent(AgentStatusIcon);

  const createWrapper = (props = {}) => {
    mockRouter = {
      push: jest.fn(),
    };

    wrapper = shallowMount(AgentFlowListItem, {
      propsData: {
        item: mockItem,
        ...props,
      },
      mocks: {
        $router: mockRouter,
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

      it('renders the link with correct href', () => {
        expect(findLink().exists()).toBe(true);
        expect(findLink().attributes('href')).toBe(
          `${mockItem.project.webUrl}/-/automate/agent-sessions/1`,
        );
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

      describe('link click handling', () => {
        it('uses router navigation for regular clicks', () => {
          const event = { metaKey: false, ctrlKey: false, preventDefault: jest.fn() };
          findLink().vm.$emit('click', event);

          expect(event.preventDefault).toHaveBeenCalled();
          expect(mockRouter.push).toHaveBeenCalledWith({
            name: AGENTS_PLATFORM_SHOW_ROUTE,
            params: { id: 1 },
          });
        });

        it.each`
          modifier     | metaKey  | ctrlKey
          ${'Command'} | ${true}  | ${false}
          ${'Ctrl'}    | ${false} | ${true}
        `('allows browser navigation for $modifier+click', ({ metaKey, ctrlKey }) => {
          const event = { metaKey, ctrlKey, preventDefault: jest.fn() };
          findLink().vm.$emit('click', event);

          expect(event.preventDefault).not.toHaveBeenCalled();
          expect(mockRouter.push).not.toHaveBeenCalled();
        });
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

    describe('when project webUrl is not available', () => {
      it('renders link with null href', () => {
        getTimeago.mockReturnValue(mockTimeago);
        mockTimeago.format.mockReturnValue('2 days ago');
        createWrapper({
          item: {
            ...mockItem,
            project: {
              ...mockItem.project,
              webUrl: null,
            },
          },
        });

        expect(findLink().attributes('href')).toBeUndefined();
      });
    });
  });
});
