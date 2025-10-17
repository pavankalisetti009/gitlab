<script>
import { GlCard, GlButton } from '@gitlab/ui';

export default {
  name: 'PurchaseCommitmentCard',
  components: {
    GlCard,
    GlButton,
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
};
</script>
<template>
  <gl-card class="gl-flex-1 gl-bg-transparent" body-class="gl-flex gl-flex-col gl-h-full">
    <h2 class="gl-font-heading gl-heading-scale-400 gl-mb-3">
      {{ s__('UsageBilling|Purchase a monthly commitment') }}
    </h2>

    <template v-if="hasCommitment">
      <p>
        {{
          s__(
            'UsageBilling|You can increase your commitment amount to extend your monthly allocation of credits.',
          )
        }}
      </p>
      <div class="gl-mt-auto">
        <gl-button variant="confirm" :href="purchaseCreditsPath">
          {{ s__('UsageBilling|Increase monthly commitment') }}
        </gl-button>
      </div>
    </template>

    <template v-else>
      <p>
        {{
          s__(
            'UsageBilling|You can purchase a monthly allocation of GitLab Credits to be shared across users.',
          )
        }}
      </p>

      <div class="gl-mt-auto">
        <gl-button variant="confirm" :href="purchaseCreditsPath">
          {{ s__('UsageBilling|Purchase monthly commitment') }}
        </gl-button>
      </div>
    </template>
  </gl-card>
</template>
