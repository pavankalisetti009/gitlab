import { GlBadge, GlIcon, GlAnimatedLoaderIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiFixInProgressBadge from 'ee/security_dashboard/components/shared/ai_fix_in_progress_badge.vue';

describe('AiFixInProgressBadge', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMountExtended(AiFixInProgressBadge);
  };

  beforeEach(() => {
    createWrapper();
  });

  const findBadge = () => wrapper.findComponent(GlBadge);
  const tooltipMessage = 'AI is currently working to resolve this vulnerability';

  it('renders a badge with the correct variant', () => {
    expect(findBadge().props()).toMatchObject({
      variant: 'info',
    });
  });

  it('renders the duo icon', () => {
    expect(wrapper.findComponent(GlIcon).props()).toMatchObject({
      name: 'tanuki-ai',
    });
  });

  it('renders the correct message', () => {
    expect(wrapper.findByTestId('ai-fix-in-progress-badge-text').text()).toBe('AI Generating Fix');
  });

  it('renders the tooltip message', () => {
    expect(findBadge().attributes('title')).toBe(tooltipMessage);
  });

  it('renders the accessible tooltip text', () => {
    const tooltip = wrapper.findByTestId('ai-fix-in-progress-badge-tooltip');

    expect(tooltip.text()).toBe(tooltipMessage);
    expect(tooltip.classes()).toContain('gl-sr-only');
  });

  it('renders the animated loader icon', () => {
    expect(wrapper.findComponent(GlAnimatedLoaderIcon).exists()).toBe(true);
  });
});
