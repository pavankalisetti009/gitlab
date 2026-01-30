<script>
import { GlButton, GlCard, GlIntersectionObserver } from '@gitlab/ui';
import TANUNKI_AI_ICON from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { PROMO_URL } from '~/constants';
import Tracking from '~/tracking';

export default {
  name: 'DuoAgentPlatformBuyCreditsCard',
  components: {
    GlButton,
    GlCard,
    GlIntersectionObserver,
  },
  mixins: [Tracking.mixin()],
  methods: {
    trackPageView() {
      this.track('pageview', { label: 'duo_agent_platform_buy_credits_card' });
    },
    trackTalkToSalesClick() {
      this.track('click_button', { label: 'duo_agent_platform_talk_to_sales' });
    },
  },
  TANUNKI_AI_ICON,
  SALES_URL: `${PROMO_URL}/sales/`,
};
</script>
<template>
  <gl-intersection-observer @appear.once="trackPageView">
    <gl-card
      footer-class="gl-bg-transparent gl-border-none gl-flex-end gl-flex gl-flex-wrap gl-gap-3"
      class="gl-justify-between"
    >
      <template #default>
        <div class="gl-flex">
          <img
            :src="$options.TANUNKI_AI_ICON"
            :alt="s__('AiPowered|Tanuki AI icon')"
            class="gl-pointer-events-none gl-size-10"
          />
          <div class="gl-ml-4">
            <h2 class="gl-m-0 gl-text-lg">{{ s__('AiPowered|Buy Credits') }}</h2>
            <p class="gl-mb-3 gl-text-size-h-display gl-font-bold">
              {{ s__('AiPowered|GitLab Duo Agent Platform') }}
            </p>
          </div>
        </div>
        <p class="gl-mb-0 gl-mt-3">
          {{
            s__(
              'AiPowered|Orchestrate AI agents across your entire software lifecycle to automate complex workflows, accelerate delivery, and keep your team in flow.',
            )
          }}
        </p>
      </template>
      <template #footer>
        <gl-button
          :href="$options.SALES_URL"
          target="_blank"
          rel="noopener noreferrer"
          variant="confirm"
          category="primary"
          data-testid="duo-agent-platform-talk-to-sales-action"
          @click="trackTalkToSalesClick"
        >
          {{ s__('AiPowered|Talk to Sales') }}
        </gl-button>
      </template>
    </gl-card>
  </gl-intersection-observer>
</template>
