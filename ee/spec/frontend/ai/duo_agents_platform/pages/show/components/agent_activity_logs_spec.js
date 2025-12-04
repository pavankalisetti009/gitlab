import { shallowMount } from '@vue/test-utils';
import { GlCollapsibleListbox, GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import AgentActivityLogs from 'ee/ai/duo_agents_platform/pages/show/components/agent_activity_logs.vue';
import ActivityLogs from 'ee/ai/duo_agents_platform/components/common/activity_logs.vue';

describe('AgentActivityLogs', () => {
  let wrapper;

  // Finders
  const findActivityLogs = () => wrapper.findComponent(ActivityLogs);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSkeletonLoader = () => wrapper.findAllComponents(GlSkeletonLoader);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  const createWrapper = (props = {}) => {
    return shallowMount(AgentActivityLogs, {
      propsData: {
        isLoading: false,
        duoMessages: [],
        ...props,
      },
    });
  };

  describe('when component is rendered', () => {
    describe('and it is loading', () => {
      beforeEach(() => {
        wrapper = createWrapper({ isLoading: true });
      });

      it('renders the fetching logs message', () => {
        expect(findSkeletonLoader().exists()).toBe(true);
      });

      it('render Detail level selector', () => {
        expect(findCollapsibleListbox().exists()).toBe(true);
      });

      it('does not render the empty state', () => {
        expect(findEmptyState().exists()).toBe(false);
      });

      it('does not render the activity logs', () => {
        expect(findActivityLogs().exists()).toBe(false);
      });
    });

    describe('when not loading', () => {
      describe('when no logs', () => {
        beforeEach(() => {
          wrapper = createWrapper({ duoMessages: [] });
        });

        it('displays the empty state', () => {
          expect(findEmptyState().exists()).toBe(true);
        });

        it('does not render ActivityLogs component', () => {
          expect(findActivityLogs().exists()).toBe(false);
        });

        it('render Detail level selector', () => {
          expect(findCollapsibleListbox().exists()).toBe(true);
        });

        it('does not renders the loading state', () => {
          expect(findSkeletonLoader().exists()).toBe(false);
        });
      });

      describe('when has logs', () => {
        const mockDuoMessages = [
          {
            id: 1,
            content: 'Start message',
            messageType: 'agent',
            status: 'success',
            timestamp: '2022-03-11T04:34:59Z',
          },
          {
            id: 2,
            content: 'Tool message',
            messageType: 'tool',
            status: 'success',
            timestamp: '2022-03-11T04:34:59Z',
            toolInfo: { name: 'read_file' },
          },
          {
            id: 3,
            content: 'Agent reasoning',
            messageType: 'agent',
            status: 'success',
            timestamp: '2022-03-11T04:34:59Z',
          },
        ];

        beforeEach(() => {
          wrapper = createWrapper({ duoMessages: mockDuoMessages });
        });

        it('renders ActivityLogs component', () => {
          expect(findActivityLogs().exists()).toBe(true);
        });

        it('renders Detail level selector', () => {
          expect(findCollapsibleListbox().exists()).toBe(true);
        });

        describe('when Full filter is selected', () => {
          beforeEach(() => {
            wrapper = createWrapper({ duoMessages: mockDuoMessages });
          });

          it('passes all logs to ActivityLogs component', () => {
            expect(findActivityLogs().props('items')).toHaveLength(3);
          });

          it('sets correct toggle text for Full filter', () => {
            expect(findCollapsibleListbox().props('toggleText')).toBe('Full view');
          });
        });

        describe('when important filter is selected', () => {
          beforeEach(() => {
            wrapper = createWrapper({ duoMessages: mockDuoMessages });
          });

          it('filters logs to show only important messages', async () => {
            expect(findActivityLogs().props('items')).toHaveLength(3);
            await findCollapsibleListbox().vm.$emit('select', 'important');

            expect(findActivityLogs().props('items')).toHaveLength(1);
            expect(findCollapsibleListbox().props('toggleText')).toBe('Concise view');
          });
        });

        describe('collapsible listbox configuration', () => {
          beforeEach(() => {
            wrapper = createWrapper({ duoMessages: mockDuoMessages });
          });

          it('configures listbox with correct props', () => {
            const listbox = findCollapsibleListbox();

            expect(listbox.attributes('id')).toBe('log-level');
            expect(listbox.props('items')).toEqual([
              { value: 'verbose', text: 'Full view' },
              { value: 'important', text: 'Concise view' },
            ]);
          });

          it('has default selected filter as Full', () => {
            expect(findCollapsibleListbox().props('toggleText')).toBe('Full view');
          });
        });

        describe('when filter selection changes', () => {
          beforeEach(() => {
            wrapper = createWrapper({ duoMessages: mockDuoMessages });
          });

          it('updates filtered logs when switching', async () => {
            expect(findActivityLogs().props('items')).toHaveLength(3);

            await findCollapsibleListbox().vm.$emit('select', 'important');

            expect(findActivityLogs().props('items')).toHaveLength(1);

            await findCollapsibleListbox().vm.$emit('select', 'Full');

            expect(findActivityLogs().props('items')).toHaveLength(3);
          });
        });
      });
    });
  });
});
