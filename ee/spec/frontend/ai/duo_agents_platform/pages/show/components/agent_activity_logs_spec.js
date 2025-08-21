import { shallowMount } from '@vue/test-utils';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { createAlert } from '~/alert';
import AgentActivityLogs from 'ee/ai/duo_agents_platform/pages/show/components/agent_activity_logs.vue';
import ActivityLogs from 'ee/ai/duo_agents_platform/components/common/activity_logs.vue';

jest.mock('~/alert');

describe('AgentActivityLogs', () => {
  let wrapper;

  // Finders
  const findActivityLogs = () => wrapper.findComponent(ActivityLogs);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findLogLevelLabel = () => wrapper.find('label[for="log-level"]');

  const createWrapper = (props = {}) => {
    return shallowMount(AgentActivityLogs, {
      propsData: {
        isLoading: false,
        agentFlowCheckpoint: '',
        ...props,
      },
    });
  };

  describe('when parsing of the checkpoint does not throw', () => {
    describe('and it is loading', () => {
      beforeEach(() => {
        wrapper = createWrapper({ isLoading: true });
      });

      it('renders the fetching logs message', () => {
        expect(wrapper.text()).toContain('Fetching logs...');
      });

      it('does not render Detail level selector', () => {
        expect(findCollapsibleListbox().exists()).toBe(false);
      });
    });

    describe('when not loading', () => {
      describe('when no logs', () => {
        beforeEach(() => {
          wrapper = createWrapper({ agentFlowCheckpoint: '' });
        });

        it('displays fallback message when no events', () => {
          expect(wrapper.text()).toContain('No logs available yet.');
        });

        it('does not render ActivityLogs component', () => {
          expect(findActivityLogs().exists()).toBe(false);
        });

        it('does not render Detail level selector', () => {
          expect(findCollapsibleListbox().exists()).toBe(false);
        });
      });

      describe('when has logs', () => {
        const validCheckpoint = JSON.stringify({
          channel_values: {
            ui_chat_log: [
              {
                id: 1,
                content: 'Start message',
                message_type: 'agent',
                status: 'success',
                timestamp: '2022-03-11T04:34:59Z',
              },
              {
                id: 2,
                content: 'Tool message',
                message_type: 'tool',
                status: 'success',
                timestamp: '2022-03-11T04:34:59Z',
                tool_info: { name: 'read_file' },
              },
              {
                id: 3,
                content: 'Agent reasoning',
                message_type: 'agent',
                status: 'success',
                timestamp: '2022-03-11T04:34:59Z',
              },
            ],
          },
        });

        beforeEach(() => {
          wrapper = createWrapper({ agentFlowCheckpoint: validCheckpoint });
        });

        it('renders ActivityLogs component', () => {
          expect(findActivityLogs().exists()).toBe(true);
        });

        it('renders Detail level selector', () => {
          expect(findCollapsibleListbox().exists()).toBe(true);
        });

        it('renders Detail level label', () => {
          expect(findLogLevelLabel().exists()).toBe(true);
          expect(findLogLevelLabel().text()).toBe('Detail level');
        });

        describe('when Full filter is selected', () => {
          beforeEach(() => {
            wrapper = createWrapper({ agentFlowCheckpoint: validCheckpoint });
          });

          it('passes all logs to ActivityLogs component', () => {
            expect(findActivityLogs().props('items')).toHaveLength(3);
          });

          it('sets correct toggle text for Full filter', () => {
            expect(findCollapsibleListbox().props('toggleText')).toBe('Full');
          });
        });

        describe('when important filter is selected', () => {
          beforeEach(() => {
            wrapper = createWrapper({ agentFlowCheckpoint: validCheckpoint });
          });

          it('filters logs to show only important messages', async () => {
            expect(findActivityLogs().props('items')).toHaveLength(3);
            await findCollapsibleListbox().vm.$emit('select', 'important');

            expect(findActivityLogs().props('items')).toHaveLength(1);
            expect(findCollapsibleListbox().props('toggleText')).toBe('Concise');
          });
        });

        describe('collapsible listbox configuration', () => {
          beforeEach(() => {
            wrapper = createWrapper({ agentFlowCheckpoint: validCheckpoint });
          });

          it('configures listbox with correct props', () => {
            const listbox = findCollapsibleListbox();

            expect(listbox.attributes('id')).toBe('log-level');
            expect(listbox.props('items')).toEqual([
              { value: 'verbose', text: 'Full' },
              { value: 'important', text: 'Concise' },
            ]);
          });

          it('has default selected filter as Full', () => {
            expect(findCollapsibleListbox().props('toggleText')).toBe('Full');
          });
        });

        describe('when filter selection changes', () => {
          beforeEach(() => {
            wrapper = createWrapper({ agentFlowCheckpoint: validCheckpoint });
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

  describe('when parsing throws', () => {
    beforeEach(() => {
      wrapper = createWrapper({ agentFlowCheckpoint: 'invalid-json' });
    });

    it('shows error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Could not display logs. Please try again.',
      });
    });

    it('displays fallback message when parsing fails', () => {
      expect(wrapper.text()).toContain('No logs available yet.');
    });

    it('does not render Detail level selector when parsing fails', () => {
      expect(findCollapsibleListbox().exists()).toBe(false);
    });
  });
});
