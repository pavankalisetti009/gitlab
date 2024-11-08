<script>
import { GlIcon, GlProgressBar } from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime_utility';
import { sprintf, s__, __ } from '~/locale';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { MINUTES_USED, PERCENTAGE_USED } from '../../constants';

export default {
  name: 'MonthlyUnitsUsageSummary',
  components: { GlIcon, GlProgressBar, HelpPageLink },
  props: {
    monthlyUnitsUsed: {
      type: String,
      required: true,
    },
    monthlyUnitsLimit: {
      type: String,
      required: true,
    },
    monthlyUnitsUsedPercentage: {
      type: String,
      required: true,
    },
    lastResetDate: {
      type: String,
      required: true,
    },
    anyProjectEnabled: {
      type: Boolean,
      required: true,
    },
    displayMinutesAvailableData: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    monthlyUsageTitle() {
      return sprintf(s__('UsageQuota|Compute usage since %{usageSince}'), {
        usageSince: formatDate(this.lastResetDate, 'mmm dd, yyyy', true),
      });
    },
    monthlyMinutesUsed() {
      return sprintf(MINUTES_USED, {
        minutesUsed: `${this.monthlyUnitsUsed} / ${this.monthlyUnitsLimit}`,
      });
    },
    percentageUsed() {
      if (this.displayMinutesAvailableData) {
        return this.monthlyUnitsUsedPercentage;
      }

      if (this.anyProjectEnabled) {
        return 0;
      }

      return null;
    },
    percentageUsedLabel() {
      if (this.percentageUsed) {
        return sprintf(PERCENTAGE_USED, {
          percentageUsed: this.percentageUsed,
        });
      }

      return __('Unlimited');
    },
  },
  CI_MINUTES_HELP_LINK_LABEL: __('Instance runners help link'),
};
</script>

<template>
  <section class="gl-flex gl-flex-wrap gl-justify-between gl-border-b-gray-100">
    <section>
      <h5 class="gl-m-0" data-testid="minutes-title">
        {{ monthlyUsageTitle }}
      </h5>
      <div data-testid="minutes-used">
        {{ monthlyMinutesUsed }}
        <help-page-link
          href="ci/pipelines/compute_minutes"
          :aria-label="$options.CI_MINUTES_HELP_LINK_LABEL"
        >
          <gl-icon name="question-o" :size="12" />
        </help-page-link>
      </div>
    </section>
    <section class="gl-w-full gl-text-right md:gl-w-1/2">
      <div data-testid="minutes-used-percentage">{{ percentageUsedLabel }}</div>
      <gl-progress-bar :value="percentageUsed" />
    </section>
  </section>
</template>
