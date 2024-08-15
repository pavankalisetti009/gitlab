<script>
import { GlIcon, GlLink, GlProgressBar } from '@gitlab/ui';

export default {
  name: 'PipelinesUsageOverview',
  components: { GlIcon, GlLink, GlProgressBar },
  inject: ['ciMinutesDisplayMinutesAvailableData'],
  props: {
    minutesTitle: {
      type: String,
      required: true,
    },
    minutesUsed: {
      type: String,
      required: true,
    },
    minutesUsedTestidSelector: {
      type: String,
      required: false,
      default: 'minutes-used',
    },
    minutesUsedPercentage: {
      type: String,
      required: true,
    },
    minutesLimit: {
      type: String,
      required: true,
    },
    helpLinkHref: {
      type: String,
      required: true,
    },
    helpLinkLabel: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <section class="gl-flex gl-justify-between gl-flex-wrap gl-border-b-gray-100">
    <section>
      <h5 class="gl-m-0" data-testid="minutes-title">
        {{ minutesTitle }}
      </h5>
      <div :data-testid="minutesUsedTestidSelector">
        {{ minutesUsed }}
        <gl-link :href="helpLinkHref" :aria-label="helpLinkLabel">
          <gl-icon name="question-o" :size="12" />
        </gl-link>
      </div>
    </section>
    <section class="gl-text-right gl-w-full md:gl-w-1/2">
      <div data-testid="minutes-used-percentage">{{ minutesUsedPercentage }}</div>
      <gl-progress-bar :value="minutesUsedPercentage" />
    </section>
  </section>
</template>
