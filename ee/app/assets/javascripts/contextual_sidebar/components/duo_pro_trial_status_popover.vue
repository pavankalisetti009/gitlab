<script>
import { GlButton, GlPopover, GlSprintf } from '@gitlab/ui';
import { GlBreakpointInstance as bp } from '@gitlab/ui/dist/utils';
import { debounce } from 'lodash';
import { formatDate } from '~/lib/utils/datetime_utility';
import { n__, sprintf } from '~/locale';
import Tracking from '~/tracking';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import {
  RESIZE_EVENT,
  RESIZE_EVENT_DEBOUNCE_MS,
  DUO_PRO_TRIAL_POPOVER_CONTENT,
  DUO_PRO_TRIAL_EXPIRED_POPOVER_TITLE,
  DUO_PRO_TRIAL_EXPIRED_POPOVER_CONTENT,
  DUO_PRO_TRIAL_POPOVER_LEARN_TITLE,
  DUO_PRO_TRIAL_LEARN_ABOUT_BUTTON_TITLE,
  DUO_PRO_TRIAL_POPOVER_PURCHASE_TITLE,
  DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY,
  DUO_PRO_TRIAL_EXPIRED_POPOVER_TRACKING_CATEGORY,
  POPOVER_HIDE_DELAY,
  WIDGET_CONTAINER_ID,
} from './constants';

export default {
  components: {
    HandRaiseLeadButton,
    GlButton,
    GlPopover,
    GlSprintf,
  },
  mixins: [Tracking.mixin()],
  inject: {
    daysRemaining: {
      type: Number,
      default: null,
    },
    purchaseNowUrl: {
      type: String,
      default: '',
    },
    trialEndDate: {
      type: Date,
      default: null,
    },
    learnAboutButtonUrl: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      disabled: false,
    };
  },
  popoverContentExpiredTrial: DUO_PRO_TRIAL_EXPIRED_POPOVER_CONTENT,
  purchaseNowTitle: DUO_PRO_TRIAL_POPOVER_PURCHASE_TITLE,
  hideDelay: { hide: POPOVER_HIDE_DELAY },
  containerId: WIDGET_CONTAINER_ID,
  popoverClasses: ['gl-p-2'],
  handRaiseLeadAttributes: {
    size: 'small',
    variant: 'confirm',
    category: 'secondary',
    class: 'gl-w-full',
    buttonTextClasses: 'gl-text-sm',
    'data-testid': 'duo-pro-trial-popover-hand-raise-lead-button',
    href: '#',
  },
  computed: {
    isTrialActive() {
      return this.daysRemaining >= 0;
    },
    formattedTrialEndDate() {
      return formatDate(this.trialEndDate, 'mmmm d', true);
    },
    popoverTitle() {
      if (!this.isTrialActive) {
        return DUO_PRO_TRIAL_EXPIRED_POPOVER_TITLE;
      }

      const i18nPopoverTitle = n__(
        "DuoProTrial|You've got %{daysRemaining} day left in your GitLab Duo Pro trial",
        "DuoProTrial|You've got %{daysRemaining} days left in your GitLab Duo Pro trial",
        this.daysRemaining,
      );

      return sprintf(i18nPopoverTitle, {
        daysRemaining: this.daysRemaining,
      });
    },
    popoverContent() {
      return sprintf(DUO_PRO_TRIAL_POPOVER_CONTENT, {
        trialEndDate: this.formattedTrialEndDate,
      });
    },
    learnAboutButtonTitle() {
      return this.isTrialActive
        ? DUO_PRO_TRIAL_POPOVER_LEARN_TITLE
        : DUO_PRO_TRIAL_LEARN_ABOUT_BUTTON_TITLE;
    },
    trialPopoverCategory() {
      return this.isTrialActive
        ? DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY
        : DUO_PRO_TRIAL_EXPIRED_POPOVER_TRACKING_CATEGORY;
    },
    handRaiseLeadBtnTracking() {
      return {
        category: this.trialPopoverCategory,
        action: 'click_button',
        label: 'contact_sales',
      };
    },
  },
  created() {
    this.debouncedResize = debounce(() => this.updateDisabledState(), RESIZE_EVENT_DEBOUNCE_MS);
    window.addEventListener(RESIZE_EVENT, this.debouncedResize);
  },
  mounted() {
    this.updateDisabledState();
  },
  beforeDestroy() {
    window.removeEventListener(RESIZE_EVENT, this.debouncedResize);
  },
  methods: {
    trackPageAction(action, options) {
      this.track(action, { category: this.trialPopoverCategory, ...options });
    },
    purchaseAction() {
      this.trackPageAction('click_button', { label: 'purchase_now' });
    },
    learnAction() {
      const label = this.isTrialActive ? 'learn_about_features' : 'learn_about_duo_pro';

      this.trackPageAction('click_button', { label });
    },
    updateDisabledState() {
      this.disabled = ['xs', 'sm'].includes(bp.getBreakpointSize());
    },
    onShown() {
      this.trackPageAction('render_popover');
    },
  },
};
</script>

<template>
  <gl-popover
    ref="popover"
    placement="rightbottom"
    boundary="viewport"
    :container="$options.containerId"
    :target="$options.containerId"
    :disabled="disabled"
    :delay="$options.hideDelay"
    :css-classes="$options.popoverClasses"
    data-testid="duo-pro-trial-status-popover"
    @shown="onShown"
  >
    <template #title>
      {{ popoverTitle }}
    </template>

    <gl-sprintf v-if="isTrialActive" :message="popoverContent">
      <template #strong="{ content }">
        <strong>{{ content }}</strong>
      </template>
    </gl-sprintf>

    <div v-else>
      <p>{{ $options.popoverContentExpiredTrial }}</p>
    </div>

    <div class="gl-mt-5">
      <gl-button
        :href="purchaseNowUrl"
        variant="confirm"
        size="small"
        class="gl-mb-3"
        block
        data-testid="purchase-now-btn"
        @click="purchaseAction"
      >
        <span class="gl-text-sm">{{ $options.purchaseNowTitle }}</span>
      </gl-button>

      <hand-raise-lead-button
        :button-attributes="$options.handRaiseLeadAttributes"
        glm-content="duo-pro-trial-status-show-group"
        :cta-tracking="handRaiseLeadBtnTracking"
      />

      <gl-button
        :href="learnAboutButtonUrl"
        category="tertiary"
        variant="confirm"
        size="small"
        class="gl-mt-3"
        block
        data-testid="learn-about-features-btn"
        @click="learnAction"
      >
        <span class="gl-text-sm">{{ learnAboutButtonTitle }}</span>
      </gl-button>
    </div>
  </gl-popover>
</template>
