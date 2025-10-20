import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { shouldDisableShortcuts } from '~/behaviors/shortcuts/shortcuts_toggle';
import { keysFor, DUO_CHAT } from '~/behaviors/shortcuts/keybindings';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';

jest.mock('~/behaviors/shortcuts/shortcuts_toggle');
jest.mock('~/behaviors/shortcuts/keybindings');

describe('NavigationRail', () => {
  let wrapper;

  const createComponent = ({
    activeTab = 'chat',
    isExpanded = true,
    showSuggestionsTab = true,
  } = {}) => {
    wrapper = shallowMountExtended(NavigationRail, {
      propsData: { activeTab, isExpanded, showSuggestionsTab },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: {
        GlButton,
      },
    });
  };

  const findChatToggle = () => wrapper.findByTestId('ai-chat-toggle');
  const findSuggestionsToggle = () => wrapper.findByTestId('ai-suggestions-toggle');
  const findSessionsToggle = () => wrapper.findByTestId('ai-sessions-toggle');

  beforeEach(() => {
    shouldDisableShortcuts.mockReturnValue(false);
    keysFor.mockReturnValue([DUO_CHAT]);

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
});
