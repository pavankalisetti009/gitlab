import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlIcon } from '@gitlab/ui';
import ActivityLogs from 'ee/ai/duo_agents_platform/components/common/activity_logs.vue';
import ActivityConnectorSvg from 'ee/ai/duo_agents_platform/components/common/activity_connector_svg.vue';
import { getTimeago } from '~/lib/utils/datetime_utility';
import NonGfmMarkdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';
import { mockItems, mockItemsWithFilepath } from './mock';

jest.mock('~/lib/utils/datetime_utility');

describe('ActivityLogs', () => {
  let wrapper;

  // Finders
  const findActivityConnectorSvg = () => wrapper.findComponent(ActivityConnectorSvg);
  const findAllListItems = () => wrapper.findAll('li');
  const findAllIcons = () => wrapper.findAllComponents(GlIcon);
  const findAllTimestamps = () => wrapper.findAll('.gl-text-subtle');
  const findFirstTitle = () => wrapper.find('strong');
  const findAllMarkdownRenderComponent = () => wrapper.findAllComponents(NonGfmMarkdown);
  const findAllCodeElements = () => wrapper.findAll('code');

  const mockTimeago = {
    format: jest.fn(),
  };

  const createWrapper = (props = {}) => {
    return shallowMount(ActivityLogs, {
      propsData: {
        items: mockItems,
        ...props,
      },
    });
  };

  describe('when component is mounted', () => {
    beforeEach(() => {
      getTimeago.mockReturnValue(mockTimeago);
      mockTimeago.format.mockReturnValue('2 minutes ago');
      wrapper = createWrapper();
    });

    it('renders the expected content', () => {
      const markdownContent = findAllMarkdownRenderComponent();
      expect(findAllListItems()).toHaveLength(3);
      expect(findAllMarkdownRenderComponent()).toHaveLength(2);
      // First item is always filtered out as its the user set goal
      expect(findAllListItems().at(0).text()).toContain('Starting workflow');
      // Markdown Content
      expect(markdownContent.at(0).props().markdown).toContain('Processing data');
      expect(markdownContent.at(1).props().markdown).toContain('Workflow completed');
    });

    it('renders the updated session triggered title', () => {
      expect(findFirstTitle().text()).toBe('Session triggered');
    });

    it('renders ActivityConnectorSvg component', () => {
      expect(findActivityConnectorSvg().exists()).toBe(true);
    });

    it('renders correct number of icons', () => {
      expect(findAllIcons()).toHaveLength(3);
    });

    it('assigns play icon to first item', () => {
      expect(findAllIcons().at(0).props('name')).toBe('play');
    });

    describe('when timestamp is required', () => {
      it('renders timestamps with timeago format in the DOM', () => {
        expect(findAllTimestamps()).toHaveLength(3);

        expect(getTimeago).toHaveBeenCalled();
        expect(mockTimeago.format).toHaveBeenCalledWith('2023-01-01T10:00:00Z');
        expect(mockTimeago.format).toHaveBeenCalledWith('2023-01-01T10:05:00Z');
        expect(mockTimeago.format).toHaveBeenCalledWith('2023-01-01T10:10:00Z');

        // Assert that timestamp is rendered with the timeago format in the DOM
        findAllTimestamps().wrappers.forEach((timestampWrapper) => {
          expect(timestampWrapper.text()).toBe('2 minutes ago');
        });
      });
    });

    describe('when filepath is not present', () => {
      it('does not render code elements', () => {
        expect(findAllCodeElements()).toHaveLength(0);
      });
    });
  });

  describe('markdown decision logic', () => {
    describe('when message is at index 0', () => {
      it.each(['user', 'agent', 'tool', 'workflow_end', 'unknown'])(
        'does not render markdown with type %s',
        ({ messageType }) => {
          wrapper = createWrapper({
            items: [
              {
                id: 0,
                content: 'New workflow item',
                message_type: messageType,
                status: 'success',
                timestamp: '2023-01-01T10:15:00Z',
              },
            ],
          });

          expect(findAllListItems()).toHaveLength(1);
          expect(findAllMarkdownRenderComponent()).toHaveLength(0);
        },
      );
    });

    describe('when message is higher than index 0', () => {
      it.each`
        messageType       | isMarkdown
        ${'user'}         | ${false}
        ${'agent'}        | ${true}
        ${'tool'}         | ${true}
        ${'workflow_end'} | ${true}
        ${'unknown'}      | ${true}
      `('does not render markdown with type $messageType', ({ messageType, isMarkdown }) => {
        wrapper = createWrapper({
          items: [
            {
              id: 0,
              content: 'initialmessage',
              message_type: 'agent',
              status: 'success',
              timestamp: '2023-01-01T10:15:00Z',
            },
            {
              id: 1,
              content: 'New workflow item',
              message_type: messageType,
              status: 'success',
              timestamp: '2023-01-01T10:15:00Z',
            },
          ],
        });

        expect(findAllListItems()).toHaveLength(2);
        expect(findAllMarkdownRenderComponent()).toHaveLength(isMarkdown ? 1 : 0);
      });
    });
  });

  describe('when items have filepath', () => {
    beforeEach(() => {
      getTimeago.mockReturnValue(mockTimeago);
      mockTimeago.format.mockReturnValue('2 minutes ago');
      wrapper = createWrapper({ items: mockItemsWithFilepath });
    });

    it('renders code elements for items with filepath', () => {
      const codeElements = findAllCodeElements();
      expect(codeElements).toHaveLength(2);
      expect(codeElements.at(0).text()).toBe('src/components/example.vue');
      expect(codeElements.at(1).text()).toBe('src/utils/helper.js');
    });

    it('does not render code element for items without filepath', () => {
      const codeElements = findAllCodeElements();
      // Should only have 2 code elements (first and third items have filepath, second doesn't)
      expect(codeElements).toHaveLength(2);
    });
  });

  describe('when resize event listener', () => {
    let addEventListenerSpy;
    let removeEventListenerSpy;

    beforeEach(() => {
      addEventListenerSpy = jest.spyOn(window, 'addEventListener');
      removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');
    });

    afterEach(() => {
      addEventListenerSpy.mockRestore();
      removeEventListenerSpy.mockRestore();
    });

    describe('when component is mounted', () => {
      beforeEach(() => {
        getTimeago.mockReturnValue(mockTimeago);
        mockTimeago.format.mockReturnValue('2 minutes ago');
        wrapper = createWrapper();
      });

      it('adds resize event listener', () => {
        expect(addEventListenerSpy).toHaveBeenCalledWith('resize', expect.any(Function));
      });
    });

    describe('when component is destroyed', () => {
      beforeEach(() => {
        getTimeago.mockReturnValue(mockTimeago);
        mockTimeago.format.mockReturnValue('2 minutes ago');
        wrapper = createWrapper();
        wrapper.destroy();
      });

      it('removes resize event listener', () => {
        expect(removeEventListenerSpy).toHaveBeenCalledWith('resize', expect.any(Function));
      });
    });
  });

  describe('when resize event is triggered', () => {
    beforeEach(async () => {
      getTimeago.mockReturnValue(mockTimeago);
      mockTimeago.format.mockReturnValue('2 minutes ago');
      wrapper = createWrapper();
      await nextTick();
    });

    it('updates iconRefs and passes different props to ActivityConnectorSvg', async () => {
      const initialTargets = findActivityConnectorSvg().props('targets');

      // Trigger resize event
      window.dispatchEvent(new Event('resize'));
      await nextTick();
      await jest.advanceTimersByTime(1000);

      const updatedTargets = findActivityConnectorSvg().props('targets');

      // Should have first and last icon refs
      expect(updatedTargets).toHaveLength(2);
      expect(updatedTargets).not.toBe(initialTargets);
    });
  });

  describe('when items prop changes', () => {
    beforeEach(() => {
      getTimeago.mockReturnValue(mockTimeago);
      mockTimeago.format.mockReturnValue('2 minutes ago');
      wrapper = createWrapper();
    });

    it('updates the rendered content', async () => {
      expect(findAllListItems()).toHaveLength(3);
      expect(findAllMarkdownRenderComponent()).toHaveLength(2);
      expect(findAllMarkdownRenderComponent().at(0).props().markdown).toBe('Processing data');

      const newItems = [
        ...mockItems,
        {
          id: 4,
          content: 'New workflow item',
          message_type: 'tool',
          status: 'success',
          timestamp: '2023-01-01T10:15:00Z',
        },
      ];

      await wrapper.setProps({ items: newItems });

      expect(findAllListItems()).toHaveLength(4);
      expect(findAllMarkdownRenderComponent()).toHaveLength(3);
      expect(findAllMarkdownRenderComponent().at(2).props().markdown).toBe('New workflow item');
    });

    describe('when items change', () => {
      beforeEach(() => {
        getTimeago.mockReturnValue(mockTimeago);
        mockTimeago.format.mockReturnValue('2 minutes ago');
        wrapper = createWrapper();
      });

      it('update the props passed to the SVG component', async () => {
        expect(findAllListItems()).toHaveLength(3);

        const newItems = [
          {
            id: 5,
            content: 'Another new item',
            message_type: 'assistant',
            status: 'success',
            timestamp: '2023-01-01T10:20:00Z',
          },
        ];

        await wrapper.setProps({ items: newItems });

        expect(findAllListItems()).toHaveLength(1);
      });
    });
  });
});
