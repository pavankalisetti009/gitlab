<script>
import { GlProgressBar, GlButton, GlLink } from '@gitlab/ui';
import { snakeCase } from 'lodash';
import { sprintf } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { InternalEvents } from '~/tracking';
import { TRIAL_WIDGET } from './constants';

export default {
  name: 'TrialWidget',
  trialWidget: TRIAL_WIDGET,
  components: {
    GlProgressBar,
    GlButton,
    GlLink,
  },
  mixins: [InternalEvents.mixin()],
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
  data() {
    return { isDismissed: false };
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
    ctaLink() {
      return this.daysRemaining < this.$options.trialWidget.trialUpgradeThresholdDays
        ? this.purchaseNowUrl
        : this.trialDiscoverPagePath;
    },
    ctaText() {
      return this.daysRemaining < this.$options.trialWidget.trialUpgradeThresholdDays
        ? this.$options.trialWidget.i18n.upgradeText
        : this.$options.trialWidget.i18n.learnMore;
    },
    ctaEventName() {
      return this.daysRemaining < this.$options.trialWidget.trialUpgradeThresholdDays
        ? this.$options.trialWidget.clickUpgradeLinkEventAction
        : this.$options.trialWidget.clickLearnMoreLinkEventAction;
    },
    isTrialActive() {
      return this.daysRemaining > 0;
    },
    isDismissable() {
      return this.groupId && this.featureId && this.dismissEndpoint;
    },
    trackingLabel() {
      return snakeCase(this.currentTrialType.name.toLowerCase());
    },
  },
  methods: {
    onCtaClick() {
      this.trackEvent(this.ctaEventName, {
        label: this.trackingLabel,
      });
    },
    onSeeUpgradeOptionsClick() {
      this.trackEvent(this.$options.trialWidget.clickSeeUpgradeOptionsLinkEventAction, {
        label: this.trackingLabel,
      });
    },
    handleDismiss() {
      axios
        .post(this.dismissEndpoint, {
          feature_name: this.featureId,
          group_id: this.groupId,
        })
        .catch((error) => {
          Sentry.captureException(error);
        });

      this.isDismissed = true;

      this.trackEvent(this.$options.trialWidget.clickDismissButtonEventAction, {
        label: this.trackingLabel,
      });
    },
  },
};
</script>

<template>
  <div
    v-if="!isDismissed"
    :id="$options.trialWidget.containerId"
    class="gl-m-2 !gl-items-start gl-rounded-tl-base gl-bg-gray-10 gl-pt-4 gl-shadow"
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
              :href="ctaLink"
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
          <div data-testid="widget-title" class="gl-w-9/10 gl-text-sm gl-text-subtle">
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
              @click.stop="onSeeUpgradeOptionsClick"
            >
              {{ $options.trialWidget.i18n.seeUpgradeOptionsText }}
            </gl-link>
          </div>
        </div>
      </div>
    </div>
    <gl-button
      v-if="isDismissable && !isTrialActive"
      class="gl-absolute gl-right-0 gl-top-0 gl-mr-2 gl-mt-2"
      size="small"
      icon="close"
      category="tertiary"
      data-testid="dismiss-btn"
      :aria-label="$options.trialWidget.i18n.dismiss"
      @click="handleDismiss"
    />
  </div>
</template>
