<script>
import { GlIcon, GlProgressBar } from '@gitlab/ui';
import { sprintf, __ } from '~/locale';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { MINUTES_USED, PERCENTAGE_USED } from '../../constants';

export default {
  name: 'AdditionalUnitsUsageSummary',
  components: { GlIcon, GlProgressBar, HelpPageLink },
  props: {
    additionalUnitsUsed: {
      type: String,
      required: true,
    },
    additionalUnitsLimit: {
      type: String,
      required: true,
    },
    additionalUnitsUsedPercentage: {
      type: String,
      required: true,
    },
  },
  computed: {
    purchasedMinutesUsed() {
      return sprintf(MINUTES_USED, {
        minutesUsed: `${this.additionalUnitsUsed} / ${this.additionalUnitsLimit}`,
      });
    },
    usagePercentageLabel() {
      return sprintf(PERCENTAGE_USED, {
        percentageUsed: this.additionalUnitsUsedPercentage,
      });
    },
  },
  ADDITIONAL_MINUTES: __('Additional units'),
};
</script>

<template>
  <section class="gl-flex gl-flex-wrap gl-justify-between gl-border-b-gray-100">
    <section>
      <h5 class="gl-m-0">
        {{ $options.ADDITIONAL_MINUTES }}
      </h5>
      <div data-testid="minutes-used">
        {{ purchasedMinutesUsed }}
        <help-page-link
          href="subscriptions/gitlab_com/compute_minutes"
          :aria-label="$options.ADDITIONAL_MINUTES"
        >
          <gl-icon name="question-o" :size="12" />
        </help-page-link>
      </div>
    </section>
    <section class="gl-w-full gl-text-right md:gl-w-1/2">
      <div data-testid="minutes-used-percentage">{{ usagePercentageLabel }}</div>
      <gl-progress-bar :value="additionalUnitsUsedPercentage" />
    </section>
  </section>
</template>
