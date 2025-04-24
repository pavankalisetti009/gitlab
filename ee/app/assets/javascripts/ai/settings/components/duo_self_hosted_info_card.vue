<script>
import { GlButton, GlCard } from '@gitlab/ui';

export default {
  name: 'DuoSelfHostedInfoCard',
  components: {
    GlButton,
    GlCard,
  },
  inject: ['duoSelfHostedPath'],
};
</script>
<template>
  <gl-card
    header-class="gl-bg-transparent gl-border-none gl-pb-0"
    footer-class="gl-bg-transparent gl-border-none gl-flex-end"
  >
    <template #header>
      <h2 class="gl-m-0 gl-text-lg">
        {{ s__('AiPowered|GitLab Duo Self-Hosted') }}
      </h2>
      <p
        data-testid="duo-self-hosted-card-secondary-header"
        class="gl-m-0 gl-text-size-h-display gl-font-bold"
      >
        {{ s__('AiPowered|Configure AI features') }}
      </p>
    </template>
    <template #default>
      <p data-testid="duo-self-hosted-card-description" class="gl-mb-0 gl-pb-0 gl-text-subtle">
        {{ s__('AiPowered|Assign self-hosted models to specific AI-native features.') }}
      </p>
    </template>
    <template #footer>
      <div>
        <gl-button :to="duoSelfHostedPath" category="primary" variant="confirm"
          >{{ s__('AiPowered|Configure GitLab Duo Self-Hosted') }}
        </gl-button>
      </div>
    </template>
  </gl-card>
</template>
