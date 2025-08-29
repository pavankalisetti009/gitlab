import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';

describe('NavigationRail', () => {
  let wrapper;

  const createComponent = ({ isExpanded = true } = {}) => {
    wrapper = shallowMountExtended(NavigationRail, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        isExpanded,
      },
      stubs: {
        GlButton,
      },
    });
  };

  const findChatToggle = () => wrapper.findByTestId('ai-chat-toggle');

  it('sets the correct aria-label for chat toggle', () => {
    createComponent();

    expect(findChatToggle().attributes('aria-label')).toBe('GitLab Duo Chat');
  });

  it('expands the chat panel if chat toggle is clicked', async () => {
    createComponent({ isExpanded: false });

    findChatToggle().trigger('click');
    await nextTick();

    expect(wrapper.emitted('toggleAIPanel')).toEqual([[true]]);
  });

  it('does not emit toggleAIPanel when button is clicked and the chat panel is already expanded', async () => {
    createComponent({ isExpanded: true });

    await findChatToggle().trigger('click');
    expect(wrapper.emitted('toggleAIPanel')).toBeUndefined();
  });
});
