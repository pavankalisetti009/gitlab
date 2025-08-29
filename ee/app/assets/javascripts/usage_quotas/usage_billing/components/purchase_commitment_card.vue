<script>
import { GlCard, GlButton } from '@gitlab/ui';

export default {
  name: 'PurchaseCommitmentCard',
  components: {
    GlCard,
    GlButton,
  },
  inject: ['purchaseCommitmentUrl'],
};
</script>
<template>
  <gl-card class="gl-flex-1 gl-bg-transparent" body-class="gl-flex gl-flex-col gl-h-full">
    <h2 class="gl-font-heading gl-heading-scale-400 gl-mb-3">
      {{ s__('UsageBilling|Purchase a monthly commitment') }}
    </h2>
    <p>
      {{
        s__(
          'UsageBilling|You can increase your commitment amount to extend your monthly allocation of tokens.',
        )
      }}
    </p>

    <div class="gl-mt-auto">
      <gl-button variant="confirm" :href="purchaseCommitmentUrl">
        {{ s__('UsageBilling|Increase monthly commitment') }}
      </gl-button>
    </div>
  </gl-card>
</template>
