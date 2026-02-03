<script>
import { GlCard, GlSprintf, GlLink, GlButton } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { PROMO_URL } from '~/constants';

export default {
  name: 'UpgradeToPremiumCard',
  components: {
    GlCard,
    GlSprintf,
    GlLink,
    GlButton,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    isSaas: { default: true },
    upgradeButtonPath: { default: null },
  },
  computed: {
    unlockMoreCreditsLink() {
      const deploymentParam = this.isSaas ? '' : '?deployment=self-managed-deployment';
      return `${PROMO_URL}/pricing${deploymentParam}`;
    },
    upgradeButtonLink() {
      return gon.subscriptions_url;
    },
  },
};
</script>
<template>
  <gl-card
    class="gl-flex gl-flex-1 gl-flex-col gl-border-feedback-brand gl-bg-feedback-brand"
    body-class="gl-p-5 gl-flex gl-flex-col gl-h-full"
  >
    <div>
      <h2 class="gl-heading-scale-400 gl-mb-3">
        {{ s__('AiPowered|Unlock more credits with Premium') }}
      </h2>
      <gl-sprintf
        :message="
          s__(
            'AiPowered|Upgrade to keep using GitLab Duo Agent Platform and access a broad credit allocation. Learn more about %{linkStart}GitLab Credit pricing%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link
            :href="unlockMoreCreditsLink"
            target="_blank"
            data-event-action="click_link"
            data-event-label="gitlab_credit_pricing"
            data-event-property="upgrade_to_premium_card"
          >
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </div>
    <div class="gl-mt-5">
      <gl-button
        :href="upgradeButtonLink"
        variant="confirm"
        data-event-action="click_CTA"
        data-event-label="upgrade_to_premium"
        data-event-property="upgrade_to_premium_card"
      >
        {{ __('Upgrade to Premium') }}
      </gl-button>
    </div>
  </gl-card>
</template>
