import { computed } from 'vue';

export function useAiBetaBadge() {
  const showBetaBadge = computed(() => !window.gon?.ai_duo_agent_platform_ga_rollout);

  return {
    showBetaBadge,
  };
}
