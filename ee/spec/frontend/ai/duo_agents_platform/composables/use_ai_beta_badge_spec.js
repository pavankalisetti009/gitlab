import { useAiBetaBadge } from 'ee/ai/duo_agents_platform/composables/use_ai_beta_badge';

describe('useAiBetaBadge', () => {
  describe('showBetaBadge', () => {
    it('returns true when ai_duo_agent_platform_ga_rollout is false', () => {
      window.gon = { ai_duo_agent_platform_ga_rollout: false };
      const { showBetaBadge } = useAiBetaBadge();

      expect(showBetaBadge.value).toBe(true);
    });

    it('returns false when ai_duo_agent_platform_ga_rollout is true', () => {
      window.gon = { ai_duo_agent_platform_ga_rollout: true };
      const { showBetaBadge } = useAiBetaBadge();

      expect(showBetaBadge.value).toBe(false);
    });

    it('returns true when ai_duo_agent_platform_ga_rollout is undefined', () => {
      window.gon = {};
      const { showBetaBadge } = useAiBetaBadge();

      expect(showBetaBadge.value).toBe(true);
    });
  });
});
