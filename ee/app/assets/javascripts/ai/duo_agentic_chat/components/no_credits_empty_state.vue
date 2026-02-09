<script>
import { GlButton } from '@gitlab/ui';
import tanukiAiSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';

export default {
  name: 'NoCreditsEmptyState',
  components: {
    GlButton,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    isTrial: {
      type: Boolean,
      required: false,
      default: false,
    },
    buyAddonPath: {
      type: String,
      required: false,
      default: '',
    },
    canBuyAddon: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    headline() {
      return this.isTrial
        ? s__('DuoAgenticChat|No credits remain on your trial')
        : s__('DuoAgenticChat|No credits remain for this billing period');
    },
    description() {
      return this.isTrial
        ? s__(
            'DuoAgenticChat|Upgrade to a paid subscription or turn off the Agentic toggle to start a new conversation.',
          )
        : s__(
            'DuoAgenticChat|Purchase more credits or turn off the Agentic toggle to start a new conversation.',
          );
    },
    primaryCtaText() {
      return this.isTrial
        ? s__('DuoAgenticChat|Upgrade to Premium')
        : s__('DuoAgenticChat|Purchase more credits');
    },
    showPrimaryCta() {
      return this.canBuyAddon && this.buyAddonPath;
    },
  },
  mounted() {
    this.trackEvent('view_duo_agentic_no_credits_empty_state', { label: this.trackingLabel() });
  },
  methods: {
    trackingLabel() {
      return this.isTrial ? 'trial' : 'paid';
    },
    onLearnMoreClick() {
      this.trackEvent('click_duo_agentic_no_credits_learn_more', { label: this.trackingLabel() });
    },
    onPrimaryCtaClick() {
      const event = this.isTrial
        ? 'click_duo_agentic_no_credits_upgrade_premium'
        : 'click_duo_agentic_no_credits_purchase_credits';
      this.trackEvent(event, { label: this.trackingLabel() });
    },
  },
  learnMorePath: helpPagePath('user/duo_agent_platform/_index'),
  tanukiAiSvgUrl,
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4 gl-py-8"
    data-testid="no-credits-empty-state"
  >
    <img
      :src="$options.tanukiAiSvgUrl"
      class="gl-h-10 gl-w-10"
      :alt="s__('DuoAgenticChat|GitLab Duo AI assistant')"
    />
    <h2 class="gl-my-0 gl-text-size-h2">
      {{ headline }}
    </h2>
    <p class="gl-text-subtle">
      {{ description }}
    </p>
    <div class="gl-flex gl-gap-3">
      <gl-button
        :href="$options.learnMorePath"
        target="_blank"
        data-testid="learn-more-button"
        @click="onLearnMoreClick"
      >
        {{ s__('DuoAgenticChat|Learn more') }}
      </gl-button>
      <gl-button
        v-if="showPrimaryCta"
        :href="buyAddonPath"
        variant="confirm"
        category="primary"
        data-testid="primary-cta"
        @click="onPrimaryCtaClick"
      >
        {{ primaryCtaText }}
      </gl-button>
    </div>
  </div>
</template>
