<script>
import { GlProgressBar, GlIcon, GlButton } from '@gitlab/ui';
import { removeTrialSuffix } from 'ee/billings/billings_util';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import { WIDGET, WIDGET_CONTAINER_ID } from './constants';

const { i18n, trackingEvents } = WIDGET;
const trackingMixin = Tracking.mixin();

export default {
  components: {
    GlProgressBar,
    GlIcon,
    GlButton,
  },
  mixins: [trackingMixin],
  inject: {
    trialDaysUsed: {},
    trialDuration: {},
    navIconImagePath: {},
    percentageComplete: {},
    planName: {},
    trialDiscoverPagePath: {},
  },
  i18n,
  containerId: WIDGET_CONTAINER_ID,
  computed: {
    isTrialActive() {
      return this.percentageComplete <= 100;
    },
    widgetTitle() {
      if (this.isTrialActive) {
        return sprintf(i18n.widgetTitle, { planName: removeTrialSuffix(this.planName) });
      }
      return i18n.widgetTitleExpiredTrial;
    },
    widgetRemainingDays() {
      return sprintf(i18n.widgetRemainingDays, {
        daysUsed: this.trialDaysUsed,
        duration: this.trialDuration,
      });
    },
    trackingOptions() {
      return this.isTrialActive
        ? trackingEvents.activeTrialOptions
        : trackingEvents.trialEndedOptions;
    },
  },
  methods: {
    onLearnAboutFeaturesClick() {
      this.track(trackingEvents.action, { ...this.trackingOptions, label: 'learn_about_features' });
    },
  },
};
</script>

<template>
  <div
    :id="$options.containerId"
    data-testid="trial-widget-menu"
    class="gl-flex gl-w-full gl-flex-col gl-items-stretch"
  >
    <div v-if="isTrialActive">
      <div class="gl-flex gl-w-full gl-items-center">
        <span class="nav-icon-container svg-container gl-mb-1 gl-mr-3">
          <!-- eslint-disable @gitlab/vue-require-i18n-attribute-strings -->
          <img alt="" :src="navIconImagePath" width="16" class="svg" />
        </span>
        <span class="nav-item-name gl-grow">
          {{ widgetTitle }}
        </span>
        <span class="gl-mr-auto gl-overflow-hidden gl-whitespace-nowrap gl-text-sm">
          {{ widgetRemainingDays }}
        </span>
      </div>
      <div class="gl-mt-2 gl-flex gl-items-stretch">
        <gl-progress-bar :value="percentageComplete" class="gl-grow" aria-hidden="true" />
      </div>

      <gl-button
        :href="trialDiscoverPagePath"
        variant="link"
        size="small"
        class="gl-mt-3 gl-underline"
        data-testid="learn-about-features-btn"
        :title="$options.i18n.learnAboutButtonTitle"
        @click.stop="onLearnAboutFeaturesClick()"
      >
        {{ $options.i18n.learnAboutButtonTitle }}
      </gl-button>
    </div>
    <div v-else class="gl-flex gl-w-full gl-gap-4 gl-px-2">
      <gl-icon name="information-o" class="gl-shrink-0 !gl-text-blue-600" />
      <div>
        <div class="gl-font-bold">
          {{ widgetTitle }}
        </div>
        <div class="gl-mt-3">
          {{ $options.i18n.widgetBodyExpiredTrial }}
          <gl-button
            :href="trialDiscoverPagePath"
            class="gl-mb-1 !gl-text-default gl-underline"
            variant="link"
            size="small"
            data-testid="learn-about-features-btn"
            :title="$options.i18n.learnAboutButtonTitle"
            @click.stop="onLearnAboutFeaturesClick()"
          >
            {{ $options.i18n.learnAboutButtonTitle }}
          </gl-button>
        </div>
      </div>
    </div>
  </div>
</template>
