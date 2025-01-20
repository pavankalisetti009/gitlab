<script>
import { GlProgressBar, GlButton, GlLink } from '@gitlab/ui';
import { snakeCase } from 'lodash';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import { sprintf } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { InternalEvents } from '~/tracking';
import {
  DUO_PRO,
  TRIAL_WIDGET_REMAINING_DAYS,
  TRIAL_WIDGET_LEARN_MORE,
  TRIAL_WIDGET_UPGRADE_TEXT,
  TRIAL_WIDGET_SEE_UPGRADE_OPTIONS,
  TRIAL_WIDGET_DISMISS,
  TRIAL_WIDGET_CONTAINER_ID,
  TRIAL_WIDGET_UPGRADE_THRESHOLD_DAYS,
  TRIAL_WIDGET_CLICK_UPGRADE,
  TRIAL_WIDGET_CLICK_LEARN_MORE,
  TRIAL_WIDGET_CLICK_SEE_UPGRADE,
  TRIAL_WIDGET_CLICK_DISMISS,
  HAND_RAISE_LEAD_ATTRIBUTES,
  TRIAL_TYPES_CONFIG,
} from './constants';

export default {
  name: 'TrialWidget',

  components: {
    GlProgressBar,
    GlButton,
    GlLink,
    HandRaiseLeadButton,
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

  trialWidget: {
    containerId: TRIAL_WIDGET_CONTAINER_ID,
    dismissLabel: TRIAL_WIDGET_DISMISS,
    upgradeOptionsText: TRIAL_WIDGET_SEE_UPGRADE_OPTIONS,
    upgradeThresholdDays: TRIAL_WIDGET_UPGRADE_THRESHOLD_DAYS,
  },

  handRaiseLeadAttributes: HAND_RAISE_LEAD_ATTRIBUTES,

  data() {
    return {
      isDismissed: false,
    };
  },

  computed: {
    currentTrialType() {
      return TRIAL_TYPES_CONFIG[this.trialType];
    },

    isWithinUpgradeThreshold() {
      return this.daysRemaining < TRIAL_WIDGET_UPGRADE_THRESHOLD_DAYS;
    },

    widgetRemainingDays() {
      return sprintf(TRIAL_WIDGET_REMAINING_DAYS, {
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
      return this.isWithinUpgradeThreshold ? this.purchaseNowUrl : this.trialDiscoverPagePath;
    },

    ctaText() {
      return this.isWithinUpgradeThreshold ? TRIAL_WIDGET_UPGRADE_TEXT : TRIAL_WIDGET_LEARN_MORE;
    },

    ctaEventName() {
      return this.isWithinUpgradeThreshold
        ? TRIAL_WIDGET_CLICK_UPGRADE
        : TRIAL_WIDGET_CLICK_LEARN_MORE;
    },

    ctaUseHandRaiseLead() {
      return this.isWithinUpgradeThreshold && this.trialType !== DUO_PRO;
    },

    ctaHandRaiseLeadTracking() {
      return {
        category: 'trial_widget',
        action: 'click_button',
        label: `${this.trialType}_contact_sales`,
      };
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
      this.trackEvent(TRIAL_WIDGET_CLICK_SEE_UPGRADE, {
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

      this.trackEvent(TRIAL_WIDGET_CLICK_DISMISS, {
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
            class="gl-text-md gl-mb-4 gl-font-bold gl-text-neutral-700"
          >
            {{ widgetTitle }}
          </div>
          <gl-progress-bar
            :value="percentageComplete"
            class="custom-gradient-progress gl-mb-4 gl-bg-purple-50"
            aria-hidden="true"
          />
          <div class="gl-flex gl-w-full gl-justify-between">
            <span class="gl-text-sm gl-text-neutral-700">
              {{ widgetRemainingDays }}
            </span>
            <gl-link
              v-if="!ctaUseHandRaiseLead"
              :href="ctaLink"
              class="gl-text-sm gl-font-bold gl-no-underline hover:gl-no-underline"
              size="small"
              data-testid="learn-about-features-btn"
              :title="ctaText"
              @click.stop="onCtaClick"
            >
              {{ ctaText }}
            </gl-link>
            <hand-raise-lead-button
              v-if="ctaUseHandRaiseLead"
              :button-attributes="$options.handRaiseLeadAttributes"
              :button-text="ctaText"
              :cta-tracking="ctaHandRaiseLeadTracking"
              glm-content="trial-widget-upgrade-button"
              data-testid="cta-hand-raise-lead-btn"
              class="gl-font-bold"
              @click.stop="onCtaClick"
            />
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
              {{ $options.trialWidget.upgradeOptionsText }}
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
      :aria-label="$options.trialWidget.dismissLabel"
      @click="handleDismiss"
    />
  </div>
</template>
