import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { shouldDisableShortcuts } from '~/behaviors/shortcuts/shortcuts_toggle';
import { keysFor, DUO_CHAT } from '~/behaviors/shortcuts/keybindings';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';
import NewChatButton from 'ee/ai/components/new_chat_button.vue';

jest.mock('~/behaviors/shortcuts/shortcuts_toggle');
jest.mock('~/behaviors/shortcuts/keybindings');

describe('NavigationRail', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(NavigationRail, {
      propsData: {
        activeTab: 'chat',
        isExpanded: true,
        showSuggestionsTab: true,
        chatDisabledReason: '',
        projectId: 'gid://gitlab/Project/123',
        namespaceId: 'gid://gitlab/Namespace/456',
        isAgenticMode: true,
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const findChatButton = () => wrapper.findByTestId('ai-chat-toggle');
  const findHistoryButton = () => wrapper.findByTestId('ai-history-toggle');
  const findSuggestionsButton = () => wrapper.findByTestId('ai-suggestions-toggle');
  const findSessionsButton = () => wrapper.findByTestId('ai-sessions-toggle');
  const findNewChatButton = () => wrapper.findComponent(NewChatButton);

  beforeEach(() => {
    shouldDisableShortcuts.mockReturnValue(false);
    keysFor.mockReturnValue([DUO_CHAT]);
  });

  describe('NewChatButton', () => {
    beforeEach(() => {
      createComponent({
        projectId: 'proj-1',
        namespaceId: 'ns-1',
        isAgenticMode: true,
        activeTab: 'chat',
        isExpanded: true,
      });
    });

    it('passes correct props', () => {
      expect(findNewChatButton().props()).toMatchObject({
        projectId: 'proj-1',
        namespaceId: 'ns-1',
        isAgentSelectEnabled: true,
        activeTab: 'chat',
        isExpanded: true,
        isChatDisabled: false,
      });
    });

    it('emits new-chat event with agent', async () => {
      await findNewChatButton().vm.$emit('new-chat', { id: 'agent1' });
      expect(wrapper.emitted('new-chat')).toEqual([[{ id: 'agent1' }]]);
    });

    it('emits new-chat event without agent', async () => {
      await findNewChatButton().vm.$emit('new-chat');
      expect(wrapper.emitted('new-chat')).toHaveLength(1);
    });

    it('emits newChatError event', async () => {
      const error = new Error('test');
      await findNewChatButton().vm.$emit('newChatError', error);
      expect(wrapper.emitted('newChatError')).toEqual([[error]]);
    });
  });

  describe('NewChatButton when chat disabled', () => {
    it('passes isChatDisabled when chatDisabledReason is set', () => {
      createComponent({ chatDisabledReason: 'project' });
      expect(findNewChatButton().props('isChatDisabled')).toBe(true);
    });
  });

  describe.each`
    name             | testId                     | tabValue         | ariaLabel
    ${'Chat'}        | ${'ai-chat-toggle'}        | ${'chat'}        | ${'Active GitLab Duo Chat'}
    ${'History'}     | ${'ai-history-toggle'}     | ${'history'}     | ${'GitLab Duo Chat history'}
    ${'Sessions'}    | ${'ai-sessions-toggle'}    | ${'sessions'}    | ${'GitLab Duo sessions'}
    ${'Suggestions'} | ${'ai-suggestions-toggle'} | ${'suggestions'} | ${'GitLab Duo suggestions'}
  `('$name button', ({ testId, tabValue, ariaLabel }) => {
    const findButton = () => wrapper.findByTestId(testId);

    describe('default state', () => {
      beforeEach(() => {
        createComponent();
      });

      it('has arias', () => {
        expect(findButton().attributes('aria-label')).toBe(ariaLabel);
        expect(findButton().attributes('aria-expanded')).toBe('true');
      });

      it('emits handleTabToggle on click', async () => {
        await findButton().vm.$emit('click');
        expect(wrapper.emitted('handleTabToggle')).toEqual([[tabValue]]);
      });
    });

    describe('collapsed state', () => {
      beforeEach(() => {
        createComponent({ isExpanded: false });
      });

      it('has no aria-expanded when closed', () => {
        expect(findButton().attributes('aria-expanded')).toBeUndefined();
      });
    });

    describe('active state', () => {
      beforeEach(() => {
        createComponent({ activeTab: tabValue });
      });

      it('has attributes and styling', () => {
        expect(findButton().attributes('aria-selected')).toBe('true');
        expect(findButton().classes()).toContain('ai-nav-icon-active');
      });
    });

    describe('inactive state', () => {
      beforeEach(() => {
        createComponent({ activeTab: 'other' });
      });

      it('has attributes and styling', () => {
        expect(findButton().attributes('aria-selected')).toBeUndefined();
        expect(findButton().classes()).not.toContain('ai-nav-icon-active');
      });
    });

    describe('disabled state', () => {
      beforeEach(() => {
        createComponent({ chatDisabledReason: 'project' });
      });

      it('has disabled attributes and styling', () => {
        expect(findButton().attributes('aria-disabled')).toBe('true');
        expect(findButton().classes()).toContain('gl-opacity-5');
      });

      it('does not emit event on click', async () => {
        await findButton().trigger('click');
        expect(wrapper.emitted('handleTabToggle')).toBeUndefined();
      });
    });
  });

  describe('Chat button', () => {
    describe('keyboard shortcut', () => {
      it.each`
        scenario                  | shortcutsDisabled | chatDisabledReason | shouldShow
        ${'shown when enabled'}   | ${false}          | ${''}              | ${true}
        ${'hidden when disabled'} | ${true}           | ${''}              | ${false}
        ${'hidden when chat off'} | ${false}          | ${'project'}       | ${false}
      `(
        'aria-keyshortcuts is $scenario',
        ({ shortcutsDisabled, chatDisabledReason, shouldShow }) => {
          shouldDisableShortcuts.mockReturnValue(shortcutsDisabled);
          createComponent({ chatDisabledReason });
          expect(findChatButton().attributes('aria-keyshortcuts') !== undefined).toBe(shouldShow);
        },
      );
    });

    describe('tooltip', () => {
      it.each`
        isAgenticMode | expectedText
        ${true}       | ${'Current GitLab Duo Chat'}
        ${false}      | ${'Active GitLab Duo Chat'}
      `(
        'shows "$expectedText" when isAgenticMode=$isAgenticMode',
        ({ isAgenticMode, expectedText }) => {
          createComponent({ isAgenticMode });
          const tooltip = getBinding(findChatButton().element, 'gl-tooltip');
          expect(tooltip.value.title).toContain(expectedText);
        },
      );

      it('shows disabled message when chat is disabled', () => {
        createComponent({ chatDisabledReason: 'project' });
        const tooltip = getBinding(findChatButton().element, 'gl-tooltip');
        expect(tooltip.value.title).toBe(
          'An administrator has turned off GitLab Duo for this project.',
        );
      });
    });
  });

  describe('History button tooltip', () => {
    it('shows correct tooltip', () => {
      createComponent();
      expect(findHistoryButton().attributes('title')).toBe('GitLab Duo Chat history');
    });

    it('shows disabled tooltip when chat is disabled', () => {
      createComponent({ chatDisabledReason: 'project' });
      expect(findHistoryButton().attributes('title')).toBe(
        'An administrator has turned off GitLab Duo for this project.',
      );
    });
  });

  describe('Sessions button tooltip', () => {
    it('shows correct tooltip', () => {
      createComponent();
      expect(findSessionsButton().attributes('title')).toBe('GitLab Duo sessions');
    });

    it('shows disabled tooltip when chat is disabled', () => {
      createComponent({ chatDisabledReason: 'project' });
      expect(findSessionsButton().attributes('title')).toBe(
        'An administrator has turned off GitLab Duo for this project.',
      );
    });
  });

  describe('Suggestions button', () => {
    describe('conditional rendering', () => {
      it.each([true, false])('renders=%s when showSuggestionsTab=%s', (showSuggestionsTab) => {
        createComponent({ showSuggestionsTab });
        expect(findSuggestionsButton().exists()).toBe(showSuggestionsTab);
      });
    });

    describe('tooltip', () => {
      it('shows correct tooltip', () => {
        createComponent();
        expect(findSuggestionsButton().attributes('title')).toBe('GitLab Duo suggestions');
      });

      it('shows disabled tooltip when chat is disabled', () => {
        createComponent({ chatDisabledReason: 'project' });
        expect(findSuggestionsButton().attributes('title')).toBe(
          'An administrator has turned off GitLab Duo for this project.',
        );
      });
    });
  });
});
