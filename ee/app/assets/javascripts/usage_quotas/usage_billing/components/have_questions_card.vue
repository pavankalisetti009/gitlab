<script>
import { GlCard, GlButton } from '@gitlab/ui';
import { PROMO_URL } from 'jh_else_ce/lib/utils/url_utility';

export default {
  name: 'HaveQuestionsCard',
  components: {
    GlCard,
    GlButton,
  },
  btnLink: `${PROMO_URL}/sales`,
};
</script>
<template>
  <gl-card class="gl-flex-1 gl-bg-subtle" body-class="gl-flex gl-flex-col gl-h-full gl-p-5">
    <h2 class="gl-heading-scale-400 gl-mb-3">
      {{ s__('UsageBilling|Have questions?') }}
    </h2>
    <p>
      {{
        s__(
          'UsageBilling|Learn more about the upgrade process and Credits pricing options by talking to sales.',
        )
      }}
    </p>

    <div class="gl-mt-auto">
      <gl-button category="secondary" :href="$options.btnLink">
        {{ s__('UsageBilling|Contact sales') }}
      </gl-button>
    </div>
  </gl-card>
</template>
