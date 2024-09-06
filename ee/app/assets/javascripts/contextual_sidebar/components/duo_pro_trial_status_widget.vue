<script>
import { GlProgressBar, GlButton } from '@gitlab/ui';
import GITLAB_LOGO_URL from '@gitlab/svgs/dist/illustrations/gitlab_logo.svg';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import {
  DISMISS,
  DUO_PRO_TRIAL_WIDGET_TITLE,
  DUO_PRO_TRIAL_EXPIRED_WIDGET_TITLE,
  DUO_PRO_TRIAL_EXPIRED_WIDGET_BODY,
  DUO_PRO_TRIAL_LEARN_ABOUT_BUTTON_TITLE,
  DUO_PRO_TRIAL_WIDGET_DAYS_TEXT,
  WIDGET_CONTAINER_ID,
} from './constants';

export default {
  components: {
    GlProgressBar,
    GlButton,
  },
  mixins: [Tracking.mixin({ category: 'duo_pro_expired_trial' })],
  inject: {
    trialDaysUsed: {},
    trialDuration: {},
    percentageComplete: {},
    groupId: {},
    featureId: {},
    dismissEndpoint: {},
    learnAboutButtonUrl: {},
  },
  dismiss: DISMISS,
  widgetBodyExpiredTrial: DUO_PRO_TRIAL_EXPIRED_WIDGET_BODY,
  learnAboutButtonTitle: DUO_PRO_TRIAL_LEARN_ABOUT_BUTTON_TITLE,
  gitlabLogo: GITLAB_LOGO_URL,
  containerId: WIDGET_CONTAINER_ID,
  computed: {
    isTrialActive() {
      return this.percentageComplete <= 100;
    },
    isDismissable() {
      return this.groupId && this.featureId && this.dismissEndpoint;
    },
    widgetClass() {
      return {
        '!gl-items-start': true,
        'js-expired-duo-pro-trial-widget': this.isDismissable,
      };
    },
    widgetTitle() {
      if (this.isTrialActive) {
        return DUO_PRO_TRIAL_WIDGET_TITLE;
      }

      return sprintf(DUO_PRO_TRIAL_EXPIRED_WIDGET_TITLE, { duration: this.trialDuration });
    },
    widgetRemainingDays() {
      return sprintf(DUO_PRO_TRIAL_WIDGET_DAYS_TEXT, {
        daysUsed: this.trialDaysUsed,
        duration: this.trialDuration,
      });
    },
  },
  methods: {
    onLearnAboutFeaturesClick() {
      this.track('click_link', { label: 'learn_about_features' });
    },
  },
};
</script>

<template>
  <div
    :id="$options.containerId"
    :class="widgetClass"
    :data-group-id="groupId"
    :data-feature-id="featureId"
    :data-dismiss-endpoint="dismissEndpoint"
    data-testid="duo-pro-trial-widget-root-element"
  >
    <div
      data-testid="duo-pro-trial-widget-menu"
      class="gl-flex gl-w-full gl-flex-col gl-items-stretch"
    >
      <div v-if="isTrialActive">
        <div class="gl-flex gl-w-full">
          <span class="nav-icon-container svg-container gl-mr-3">
            <img :src="$options.gitlabLogo" width="16" class="svg" />
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
      </div>

      <div v-else class="gl-flex gl-w-full gl-gap-4 gl-px-2">
        <div>
          <div class="gl-font-bold">
            {{ widgetTitle }}
          </div>
          <div class="gl-mt-3">
            {{ $options.widgetBodyExpiredTrial }}
            <gl-button
              :href="learnAboutButtonUrl"
              class="gl-mb-1 !gl-text-default gl-underline"
              variant="link"
              size="small"
              data-testid="learn-about-features-btn"
              :title="$options.learnAboutButtonTitle"
              @click.stop="onLearnAboutFeaturesClick()"
            >
              {{ $options.learnAboutButtonTitle }}
            </gl-button>
          </div>
        </div>
      </div>
    </div>

    <gl-button
      v-if="isDismissable && !isTrialActive"
      class="js-close"
      size="small"
      icon="close"
      category="tertiary"
      data-testid="dismiss-btn"
      :aria-label="$options.dismiss"
    />
  </div>
</template>
