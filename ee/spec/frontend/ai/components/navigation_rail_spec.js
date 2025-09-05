import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';

describe('NavigationRail', () => {
  let wrapper;

  const createComponent = ({ activeTab = 'chat', isExpanded = true } = {}) => {
    wrapper = shallowMountExtended(NavigationRail, {
      propsData: { activeTab, isExpanded },
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
    createComponent();
  });

  it('sets the correct aria-labels for toggles', () => {
    expect(findChatToggle().attributes('aria-label')).toBe('GitLab Duo Chat');
    expect(findSuggestionsToggle().attributes('aria-label')).toBe('GitLab Duo Suggestions');
    expect(findSessionsToggle().attributes('aria-label')).toBe('GitLab Duo Sessions');
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
});
