<script>
import { GlButton, GlCard } from '@gitlab/ui';

export default {
  name: 'DuoUsageAnalyticsCard',
  components: {
    GlButton,
    GlCard,
  },
  props: {
    dashboardPath: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <gl-card
    header-class="gl-bg-transparent gl-border-none gl-pb-0"
    footer-class="gl-bg-transparent gl-border-none gl-flex-end"
  >
    <template #header>
      <h2 class="gl-heading-3 gl-mb-3 gl-font-bold">
        {{ s__('AiPowered|GitLab Credit usage analytics') }}
      </h2>
    </template>
    <template #default>
      <p class="gl-mb-0 gl-pb-0 gl-text-subtle">
        {{
          s__(
            'AiPowered|Track credit consumption across your users and monitor usage trends. View breakdowns by user to understand how your team utilizes GitLab Duo.',
          )
        }}
      </p>
    </template>
    <template #footer>
      <div>
        <gl-button :to="dashboardPath" category="primary" variant="confirm">
          {{ s__('AiPowered|View usage dashboard') }}
        </gl-button>
      </div>
    </template>
  </gl-card>
</template>
