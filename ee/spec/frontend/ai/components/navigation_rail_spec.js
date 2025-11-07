import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { shouldDisableShortcuts } from '~/behaviors/shortcuts/shortcuts_toggle';
import { keysFor, DUO_CHAT } from '~/behaviors/shortcuts/keybindings';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';
import { CHAT_MODES } from 'ee/ai/tanuki_bot/constants';
import { duoChatGlobalState } from '~/super_sidebar/constants';

jest.mock('~/behaviors/shortcuts/shortcuts_toggle');
jest.mock('~/behaviors/shortcuts/keybindings');

describe('NavigationRail', () => {
  let wrapper;

  const createComponent = ({
    activeTab = 'chat',
    isExpanded = true,
    showSuggestionsTab = true,
    chatDisabledReason = '',
  } = {}) => {
    wrapper = shallowMountExtended(NavigationRail, {
      propsData: { activeTab, isExpanded, showSuggestionsTab, chatDisabledReason },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: {
        GlButton,
      },
    });
  };

  const findChatToggle = () => wrapper.findByTestId('ai-chat-toggle');
  const findNewToggle = () => wrapper.findByTestId('ai-new-toggle');
  const findHistoryToggle = () => wrapper.findByTestId('ai-history-toggle');
  const findSuggestionsToggle = () => wrapper.findByTestId('ai-suggestions-toggle');
  const findSessionsToggle = () => wrapper.findByTestId('ai-sessions-toggle');
  const findDivider = () => wrapper.find('[name="divider"]');

  beforeEach(() => {
    shouldDisableShortcuts.mockReturnValue(false);
    keysFor.mockReturnValue([DUO_CHAT]);
    // Reset global state before each test
    duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;

    createComponent();
  });

  it('sets the correct aria-labels for toggles', () => {
    expect(findChatToggle().attributes('aria-label')).toBe('Active GitLab Duo Chat');
    expect(findSuggestionsToggle().attributes('aria-label')).toBe('GitLab Duo suggestions');
    expect(findSessionsToggle().attributes('aria-label')).toBe('GitLab Duo sessions');
  });

  it('sets the correct aria-selected attribute based on the active tab', () => {
    expect(findChatToggle().attributes('aria-selected')).toBe('true');
    expect(findSuggestionsToggle().attributes('aria-selected')).toBeUndefined();
    expect(findSessionsToggle().attributes('aria-selected')).toBeUndefined();
  });

  it('switches active tabs when a mode toggle is clicked', async () => {
    createComponent({ activeTab: 'suggestions' });
    await findChatToggle().trigger('click');

    expect(wrapper.emitted('handleTabToggle')).toEqual([['chat']]);
  });

  it('does not show keyshortcuts when shortcuts are disabled', () => {
    shouldDisableShortcuts.mockReturnValue(true);

    createComponent();

    expect(findChatToggle().attributes('aria-keyshortcuts')).toBeUndefined();
  });

  it('does not render suggestions tab when showSuggestionsTab is false', () => {
    createComponent({ showSuggestionsTab: false });

    expect(findSuggestionsToggle().exists()).toBe(false);
  });

  describe('sessions button visibility', () => {
    it('shows sessions button when in agentic mode', () => {
      duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
      createComponent();

      expect(findSessionsToggle().exists()).toBe(true);
      expect(findDivider().exists()).toBe(true);
    });

    it('hides sessions button when in classic mode', () => {
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
      createComponent();

      expect(findSessionsToggle().exists()).toBe(false);
      expect(findDivider().exists()).toBe(false);
    });
  });

  describe('when chat is disabled', () => {
    beforeEach(() => {
      createComponent({ chatDisabledReason: 'project' });
    });

    describe('all buttons', () => {
      it.each`
        buttonName       | finder
        ${'chat'}        | ${findChatToggle}
        ${'new'}         | ${findNewToggle}
        ${'history'}     | ${findHistoryToggle}
        ${'sessions'}    | ${findSessionsToggle}
        ${'suggestions'} | ${findSuggestionsToggle}
      `('sets aria-disabled on $buttonName button', ({ finder }) => {
        expect(finder().attributes('aria-disabled')).toBe('true');
        expect(finder().classes()).toContain('gl-opacity-5');
      });

      it('prevents tab toggle when clicking disabled buttons', async () => {
        await findChatToggle().trigger('click');

        expect(wrapper.emitted('handleTabToggle')).toBeUndefined();
      });

      it('disables keyboard shortcut', () => {
        expect(findChatToggle().attributes('aria-keyshortcuts')).toBeUndefined();
      });
    });

    describe('buttons with title attribute', () => {
      it.each`
        buttonName       | finder
        ${'new'}         | ${findNewToggle}
        ${'history'}     | ${findHistoryToggle}
        ${'sessions'}    | ${findSessionsToggle}
        ${'suggestions'} | ${findSuggestionsToggle}
      `('shows disabled tooltip on $buttonName button', ({ finder }) => {
        expect(finder().attributes('title')).toBe(
          'An administrator has turned off GitLab Duo for this project.',
        );
      });
    });

    describe('button with HTML tooltip', () => {
      it('shows disabled tooltip', () => {
        const tooltip = getBinding(findChatToggle().element, 'gl-tooltip');
        expect(tooltip.value.title).toBe(
          'An administrator has turned off GitLab Duo for this project.',
        );
      });
    });
  });
});
