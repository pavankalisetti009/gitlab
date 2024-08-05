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

const trackingMixin = Tracking.mixin();

export default {
  components: {
    GlProgressBar,
    GlButton,
  },
  mixins: [trackingMixin],
  inject: {
    trialDaysUsed: {},
    trialDuration: {},
    percentageComplete: {},
    widgetUrl: {},
    groupId: {},
    featureId: {},
    dismissEndpoint: {},
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
    onWidgetClick() {
      const category = this.isTrialActive ? 'trial_status_widget' : 'trial_ended_widget';

      this.track('click_link', { category, label: 'duo_pro_trial' });
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
      class="gl-flex gl-flex-col gl-items-stretch gl-w-full"
      @click="onWidgetClick"
    >
      <div v-if="isTrialActive">
        <div class="gl-flex gl-w-full">
          <span class="nav-icon-container svg-container gl-mr-3">
            <img :src="$options.gitlabLogo" width="16" class="svg" />
          </span>
          <span class="nav-item-name gl-grow">
            {{ widgetTitle }}
          </span>
          <span class="gl-whitespace-nowrap gl-overflow-hidden gl-text-sm gl-mr-auto">
            {{ widgetRemainingDays }}
          </span>
        </div>

        <div class="gl-flex gl-items-stretch gl-mt-2">
          <gl-progress-bar :value="percentageComplete" class="gl-grow" aria-hidden="true" />
        </div>
      </div>

      <div v-else class="gl-flex gl-gap-4 gl-w-full gl-px-2">
        <div>
          <div class="gl-font-bold">
            {{ widgetTitle }}
          </div>
          <div class="gl-mt-3">
            {{ $options.widgetBodyExpiredTrial }}
            {{ $options.learnAboutButtonTitle }}
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
      :aria-label="$options.dismiss"
    />
  </div>
</template>
