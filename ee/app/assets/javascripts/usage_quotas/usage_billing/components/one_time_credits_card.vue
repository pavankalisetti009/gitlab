<script>
import { GlCard, GlSprintf, GlLink } from '@gitlab/ui';
import { numberToMetricPrefix } from '~/lib/utils/number_utils';
import { PROMO_URL } from 'jh_else_ce/lib/utils/url_utility';

export default {
  name: 'OneTimeCreditsCard',
  components: {
    GlCard,
    GlSprintf,
    GlLink,
  },
  props: {
    otcRemainingCredits: {
      type: Number,
      required: true,
    },
    otcCreditsUsed: {
      type: Number,
      required: true,
    },
  },
  methods: {
    numberToMetricPrefix,
  },
  pricingLink: `${PROMO_URL}/pricing`,
};
</script>
<template>
  <gl-card class="gl-flex-1 gl-bg-transparent" body-class="gl-p-5">
    <h2 class="gl-heading-scale-400 gl-mb-2">
      {{ s__('UsageBilling|GitLab Credits - One-Time Waiver') }}
    </h2>
    <div class="gl-mb-4 gl-text-sm gl-text-subtle">
      {{ s__('UsageBilling|Used this billing period') }}
    </div>
    <div class="gl-heading-scale-600 gl-mb-3" data-testid="otc-credits-used">
      {{ numberToMetricPrefix(otcCreditsUsed) }}
    </div>
    <div class="gl-border-t gl-mb-3 gl-pt-3 gl-text-sm gl-text-subtle">
      <gl-sprintf
        :message="
          s__(
            'UsageBilling|Credits used after any included user credits and monthly commitment pool have been exhausted. Learn about %{linkStart}GitLab Credit pricing%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.pricingLink" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </div>
    <div class="gl-border-t gl-flex gl-flex-row gl-justify-between gl-pt-3 gl-text-subtle">
      <span>{{ s__('UsageBilling|One-Time Waiver credits remaining') }}</span>
      <span data-testid="otc-remaining-credits">{{
        numberToMetricPrefix(otcRemainingCredits)
      }}</span>
    </div>
  </gl-card>
</template>
