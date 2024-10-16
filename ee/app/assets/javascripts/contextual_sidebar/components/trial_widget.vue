<script>
import { GlProgressBar, GlButton, GlLink } from '@gitlab/ui';
import { snakeCase } from 'lodash';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import { TRIAL_WIDGET } from './constants';

export default {
  name: 'TrialWidget',
  trialWidget: TRIAL_WIDGET,
  components: {
    GlProgressBar,
    GlButton,
    GlLink,
  },
  mixins: [Tracking.mixin()],
  inject: {
    trialType: { default: '' },
    daysRemaining: { default: 0 },
    percentageComplete: { default: 0 },
    trialDiscoverPagePath: { default: '' },
    purchaseNowUrl: { default: '' },
    groupId: { default: '' },
    featureId: { default: '' },
    dismissEndpoint: { default: '' },
  },
  computed: {
    currentTrialType() {
      return this.$options.trialWidget.trialTypes[this.trialType];
    },
    widgetRemainingDays() {
      return sprintf(this.$options.trialWidget.i18n.widgetRemainingDays, {
        daysLeft: this.daysRemaining,
      });
    },
    widgetTitle() {
      return this.currentTrialType.widgetTitle;
    },
    expiredWidgetTitleText() {
      return this.currentTrialType.widgetTitleExpiredTrial;
    },
    ctaText() {
      return this.daysRemaining < this.$options.trialWidget.trialUpgradeThresholdDays
        ? this.$options.trialWidget.i18n.upgradeText
        : this.$options.trialWidget.i18n.learnMore;
    },
    trackingOptions() {
      const baseOptions = this.isTrialActive
        ? this.$options.trialWidget.trackingEvents.activeTrialOptions
        : this.$options.trialWidget.trackingEvents.trialEndedOptions;

      return {
        ...baseOptions,
        label: this.isTrialActive
          ? this.formatTrackingLabel(this.currentTrialType.name)
          : baseOptions.label,
        property: this.currentTrialType.name,
      };
    },
    isTrialActive() {
      return this.percentageComplete <= 100;
    },
    isDismissable() {
      return this.groupId && this.featureId && this.dismissEndpoint;
    },
  },
  methods: {
    onCtaClick() {
      this.track(this.$options.trialWidget.trackingEvents.action, this.trackingOptions);
    },
    formatTrackingLabel(str) {
      return `${snakeCase(str)}_trial`;
    },
  },
};
</script>

<template>
  <div
    :id="$options.trialWidget.containerId"
    class="gl-m-2 !gl-items-start gl-rounded-tl-base gl-bg-gray-10 gl-pt-4 gl-shadow"
    :class="{ 'js-expired-trial-widget': isDismissable }"
    :data-group-id="groupId"
    :data-feature-id="featureId"
    :data-dismiss-endpoint="dismissEndpoint"
    data-testid="trial-widget-root-element"
  >
    <div data-testid="trial-widget-menu" class="gl-flex gl-w-full gl-flex-col gl-items-stretch">
      <div v-if="isTrialActive">
        <div class="gl-flex-column gl-w-full">
          <div
            data-testid="widget-title"
            class="gl-text-md gl-text-neutral-700 gl-mb-4 gl-font-bold"
          >
            {{ widgetTitle }}
          </div>
          <gl-progress-bar
            :value="percentageComplete"
            class="custom-gradient-progress gl-mb-4 gl-bg-purple-50"
            aria-hidden="true"
          />
          <div class="gl-flex gl-w-full gl-justify-between">
            <span class="gl-text-neutral-700 gl-text-sm">
              {{ widgetRemainingDays }}
            </span>
            <gl-link
              :href="trialDiscoverPagePath"
              class="gl-text-sm gl-font-bold gl-no-underline hover:gl-no-underline"
              size="small"
              data-testid="learn-about-features-btn"
              :title="ctaText"
              @click.stop="onCtaClick"
            >
              {{ ctaText }}
            </gl-link>
          </div>
        </div>
      </div>
      <div v-else class="gl-flex gl-w-full gl-gap-4 gl-px-2">
        <div class="gl-w-full">
          <div data-testid="widget-title" class="gl-w-9/10 gl-text-sm gl-text-gray-600">
            {{ expiredWidgetTitleText }}
          </div>
          <div class="gl-mt-4 gl-text-center">
            <gl-progress-bar
              :value="100"
              class="custom-gradient-progress gl-mb-4"
              aria-hidden="true"
            />
            <gl-link
              :href="purchaseNowUrl"
              class="gl-center gl-mb-1 gl-text-sm gl-font-bold gl-text-blue-700 gl-no-underline hover:gl-no-underline"
              data-testid="upgrade-options-btn"
              :title="ctaText"
              @click.stop="onCtaClick"
            >
              {{ $options.trialWidget.i18n.seeUpgradeOptionsText }}
            </gl-link>
          </div>
        </div>
      </div>
    </div>
    <gl-button
      v-if="isDismissable && !isTrialActive"
      class="js-close gl-absolute gl-right-0 gl-top-0 gl-mr-2 gl-mt-2"
      size="small"
      icon="close"
      category="tertiary"
      data-testid="dismiss-btn"
      :aria-label="$options.trialWidget.i18n.dismiss"
    />
  </div>
</template>
