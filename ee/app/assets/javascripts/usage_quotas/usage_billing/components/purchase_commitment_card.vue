<script>
import { GlCard, GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import { PROMO_URL } from 'jh_else_ce/lib/utils/url_utility';

export default {
  name: 'PurchaseCommitmentCard',
  components: {
    GlCard,
    GlButton,
    GlSprintf,
    GlLink,
  },
  props: {
    hasCommitment: {
      required: true,
      type: Boolean,
    },
    purchaseCreditsPath: {
      required: true,
      type: String,
    },
  },
  pricingLink: `${PROMO_URL}/pricing`,
};
</script>
<template>
  <gl-card class="gl-flex-1 gl-bg-subtle" body-class="gl-flex gl-flex-col gl-h-full gl-p-5">
    <template v-if="hasCommitment">
      <h2 class="gl-heading-scale-400 gl-mb-3">
        {{ s__('UsageBilling|Increase monthly credit commitment') }}
      </h2>
      <p>
        <gl-sprintf
          :message="
            s__(
              'UsageBilling|Increase your commitment to unlock deeper discounts. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs. %{linkStart}GitLab Credit pricing%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.pricingLink" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
      <div class="gl-mt-auto">
        <gl-button variant="confirm" :href="purchaseCreditsPath">
          {{ s__('UsageBilling|Increase monthly commitment') }}
        </gl-button>
      </div>
    </template>

    <template v-else>
      <h2 class="gl-heading-scale-400 gl-mb-3">
        {{ s__('UsageBilling|Save on GitLab Credits with monthly commitment') }}
      </h2>
      <p>
        <gl-sprintf
          :message="
            s__(
              'UsageBilling|Monthly commitments offer significant discounts off list price. Share GitLab Credits across your namespace for flexibility and predictable monthly costs. Learn more about %{linkStart}GitLab Credit pricing%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.pricingLink" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>

      <div class="gl-mt-auto">
        <gl-button variant="confirm" :href="purchaseCreditsPath">
          {{ s__('UsageBilling|Purchase monthly commitment') }}
        </gl-button>
      </div>
    </template>
  </gl-card>
</template>
