import { GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentFlowListItem from 'ee/ai/duo_agents_platform/components/common/agent_flow_list_item.vue';
import AgentStatusIcon from 'ee/ai/duo_agents_platform/components/common/agent_status_icon.vue';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { getTimeago } from '~/lib/utils/datetime/timeago_utility';
import { formatAgentStatus, formatAgentDefinition } from 'ee/ai/duo_agents_platform/utils';

jest.mock('~/lib/utils/datetime/timeago_utility');
jest.mock('ee/ai/duo_agents_platform/utils');

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
    createdAt: '2024-01-01T00:00:00Z',
    updatedAt: '2024-01-01T00:00:00Z',
    workflowDefinition: 'software_development',
    latestCheckpoint: {
      duoMessages: [{ content: 'This is the last message' }],
    },
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

  beforeEach(() => {
    formatAgentStatus.mockReturnValue('Finished');
    formatAgentDefinition.mockReturnValue('Software development');
  });

  const findLink = () => wrapper.findComponent(GlLink);
  const findStatusIcon = () => wrapper.findComponent(AgentStatusIcon);
  const findItemTitle = () => wrapper.find('[data-testid="item-title"]');
  const findCreatedAt = () => wrapper.find('[data-testid="item-created-date"]');
  const findUpdatedAt = () => wrapper.find('[data-testid="item-updated-date"]');
  const findLastMessage = () => wrapper.find('[data-testid="item-last-updated-message"]');

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
    beforeEach(() => {
      getTimeago.mockReturnValue(mockTimeago);
      mockTimeago.format.mockReturnValue('2 days ago');
    });

    describe('with latestCheckpoint messages', () => {
      beforeEach(() => {
        createWrapper();
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

      it('displays the formatted agent name without project by default', () => {
        expect(findItemTitle().text()).toContain('Software development');
        expect(findItemTitle().text()).not.toContain('Test Project');
      });

      it('displays the formatted agent name with project when showProjectInfo is true', () => {
        createWrapper({ showProjectInfo: true });
        expect(findItemTitle().text()).toContain('Test Project / Software development');
      });

      it('displays the formatted workflow id', () => {
        expect(findItemTitle().text()).toContain('#1');
      });

      it('displays the last message truncated', () => {
        expect(findLastMessage().text()).toContain('This is the last message');
        expect(findLastMessage().classes()).toContain('gl-truncate');
      });

      it('displays the created time', () => {
        expect(wrapper.text()).toContain('Created');
        expect(findCreatedAt().text()).toContain('2 days ago');
      });

      it('displays the formatted updated time', () => {
        expect(findUpdatedAt().text()).toContain('2 days ago');
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

    describe('without latestCheckpoint messages', () => {
      it('displays last status message when no messages available', () => {
        createWrapper({
          item: {
            ...mockItem,
            latestCheckpoint: null,
          },
        });

        expect(wrapper.text()).toContain('Last updated');
      });
    });

    describe('when project webUrl is not available', () => {
      it('renders link with null href', () => {
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
