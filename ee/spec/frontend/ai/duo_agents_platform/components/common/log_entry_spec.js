import { GlButton, GlCollapse } from '@gitlab/ui';
import { MessageToolKvSection } from '@gitlab/duo-ui';
import { shallowMount } from '@vue/test-utils';
import LogEntry from 'ee/ai/duo_agents_platform/components/common/log_entry.vue';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import NonGfmMarkdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { mockItems, mockItemsWithFilepath } from './mock';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('LogEntry', () => {
  let wrapper;

  const findTitle = () => wrapper.find('[data-testid="log-entry-title"]');
  const findTimestamp = () => wrapper.findComponent(TimeAgoTooltip);
  const findMarkdown = () => wrapper.findComponent(NonGfmMarkdown);
  const findPlainText = () => wrapper.find('[data-testid="log-entry-plain-text"]');
  const findCollapseButton = () => wrapper.findComponent(GlButton);
  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findToolKvSection = () => wrapper.findComponent(MessageToolKvSection);
  const findCodeElement = () => wrapper.find('[data-testid="log-entry-file-path"]');

  const createWrapper = (props = {}) => {
    return shallowMount(LogEntry, {
      propsData: {
        item: mockItems[0],
        index: 1,
        ...props,
      },
    });
  };

  describe('title rendering', () => {
    describe('when index is 0', () => {
      it('renders "Session triggered" title', () => {
        wrapper = createWrapper({ index: 0 });
        expect(findTitle().text()).toBe('Session triggered');
      });
    });

    describe('when index is greater than 0', () => {
      it('renders title in DOM', () => {
        wrapper = createWrapper({ index: 1 });
        expect(findTitle().exists()).toBe(true);
      });
    });
  });

  describe('timestamp rendering', () => {
    it('renders TimeAgoTooltip component with correct props', () => {
      wrapper = createWrapper();
      const timestamp = findTimestamp();

      expect(timestamp.exists()).toBe(true);
      expect(timestamp.props('time')).toBe(mockItems[0].timestamp);
      expect(timestamp.props('cssClass')).toBe('gl-text-subtle');
    });
  });

  describe('content rendering', () => {
    describe('when isMarkdown is true (messageType !== "user" and index > 0)', () => {
      it('renders markdown element', () => {
        wrapper = createWrapper({
          item: { ...mockItems[0], messageType: 'agent' },
          index: 1,
        });

        expect(findMarkdown().exists()).toBe(true);
      });
    });

    describe('when isMarkdown is false (messageType === "user" or index === 0)', () => {
      it('renders plain text for user messages', () => {
        wrapper = createWrapper({
          item: { ...mockItems[0], messageType: 'user' },
          index: 1,
        });

        expect(findMarkdown().exists()).toBe(false);
        expect(findPlainText().text()).toBe(mockItems[0].content);
      });

      it('renders plain text when index is 0', () => {
        wrapper = createWrapper({
          item: { ...mockItems[0], messageType: 'agent' },
          index: 0,
        });

        expect(findMarkdown().exists()).toBe(false);
        expect(findPlainText().text()).toBe(mockItems[0].content);
      });
    });
  });

  describe('tool info functionality', () => {
    describe('when item has toolInfo', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          item: mockItemsWithFilepath[0],
          index: 1,
        });
      });

      it('renders collapse button', () => {
        expect(findCollapseButton().exists()).toBe(true);
      });

      it('collapse button has chevron-right icon initially', () => {
        expect(findCollapseButton().props('icon')).toBe('chevron-right');
      });

      it('renders GlCollapse component', () => {
        expect(findCollapse().exists()).toBe(true);
      });

      it('collapse is initially hidden', () => {
        expect(findCollapse().props('visible')).toBe(false);
      });

      it('renders MessageToolKvSection with correct props', () => {
        const kvSection = findToolKvSection();
        expect(kvSection.exists()).toBe(true);
        expect(kvSection.props('title')).toBe('Request');
        expect(kvSection.props('value')).toEqual({
          file_path: 'src/components/example.vue',
        });
      });

      it('toggles collapse visibility when button is clicked', async () => {
        expect(findCollapseButton().props('icon')).toBe('chevron-right');
        expect(findCollapse().props('visible')).toBe(false);

        await findCollapseButton().vm.$emit('click');

        expect(findCollapseButton().props('icon')).toBe('chevron-down');
        expect(findCollapse().props('visible')).toBe(true);
      });

      it('toggles collapse back when button is clicked again', async () => {
        await findCollapseButton().vm.$emit('click');
        expect(findCollapse().props('visible')).toBe(true);

        await findCollapseButton().vm.$emit('click');

        expect(findCollapseButton().props('icon')).toBe('chevron-right');
        expect(findCollapse().props('visible')).toBe(false);
      });
    });

    describe('when item does not have toolInfo', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          item: mockItems[0],
          index: 1,
        });
      });

      it('does not render collapse button', () => {
        expect(findCollapseButton().exists()).toBe(false);
      });

      it('does not render GlCollapse', () => {
        expect(findCollapse().exists()).toBe(false);
      });
    });

    describe('when toolInfo has invalid JSON', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          item: {
            ...mockItems[0],
            toolInfo: 'invalid json{',
          },
          index: 1,
        });
      });

      it('calls captureException', () => {
        expect(captureException).toHaveBeenCalled();
      });

      it('does not render collapse button', () => {
        expect(findCollapseButton().exists()).toBe(false);
      });
    });
  });

  describe('file path rendering', () => {
    describe('when item has file_path in toolInfo', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          item: mockItemsWithFilepath[0],
          index: 1,
        });
      });

      it('renders code element with file path', () => {
        const codeElement = findCodeElement();
        expect(codeElement.exists()).toBe(true);
        expect(codeElement.text()).toBe('src/components/example.vue');
      });
    });

    describe('when item does not have file_path in toolInfo', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          item: mockItems[0],
          index: 1,
        });
      });

      it('does not render code element', () => {
        expect(findCodeElement().exists()).toBe(false);
      });
    });
  });
});
