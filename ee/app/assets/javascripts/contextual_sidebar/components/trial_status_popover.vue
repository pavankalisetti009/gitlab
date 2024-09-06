<script>
import { GlButton, GlPopover, GlSprintf } from '@gitlab/ui';
import { GlBreakpointInstance as bp } from '@gitlab/ui/dist/utils';
import { debounce } from 'lodash';
import { removeTrialSuffix } from 'ee/billings/billings_util';
import { formatDate } from '~/lib/utils/datetime_utility';
import { n__, sprintf } from '~/locale';
import Tracking from '~/tracking';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import { PQL_MODAL_ID } from 'ee/hand_raise_leads/hand_raise_lead/constants';
import { POPOVER, RESIZE_EVENT, WIDGET_CONTAINER_ID } from './constants';

const {
  i18n,
  trackingEvents,
  trialEndDateFormatString,
  resizeEventDebounceMS,
  disabledBreakpoints,
} = POPOVER;
const trackingMixin = Tracking.mixin();

export default {
  components: {
    HandRaiseLeadButton,
    GlButton,
    GlPopover,
    GlSprintf,
  },
  mixins: [trackingMixin],
  inject: {
    daysRemaining: {},
    planName: {},
    plansHref: {},
    trialEndDate: {},
    trialDiscoverPagePath: {},
  },
  data() {
    return {
      disabled: false,
    };
  },
  i18n,
  containerId: WIDGET_CONTAINER_ID,
  handRaiseLeadAttributes: {
    size: 'small',
    variant: 'confirm',
    category: 'secondary',
    class: 'gl-w-full',
    buttonTextClasses: 'gl-text-sm',
    href: '#',
    'data-testid': 'trial-popover-hand-raise-lead-button',
  },
  modalId: PQL_MODAL_ID,
  computed: {
    isTrialActive() {
      return this.daysRemaining >= 0;
    },
    formattedTrialEndDate() {
      return formatDate(this.trialEndDate, trialEndDateFormatString, true);
    },
    planNameWithoutTrial() {
      return removeTrialSuffix(this.planName);
    },
    popoverTitle() {
      if (!this.isTrialActive) {
        return i18n.popoverTitleExpiredTrial;
      }

      const i18nPopoverTitle = n__(
        "Trials|You've got %{daysRemaining} day remaining on GitLab %{planName}!",
        "Trials|You've got %{daysRemaining} days remaining on GitLab %{planName}!",
        this.daysRemaining,
      );

      return sprintf(i18nPopoverTitle, {
        daysRemaining: this.daysRemaining,
        planName: this.planName,
      });
    },
    popoverContent() {
      return sprintf(i18n.popoverContent, {
        trialEndDate: this.formattedTrialEndDate,
      });
    },
    cssClasses() {
      const classList = ['gl-p-2'];

      if (!this.isTrialActive) {
        classList.push('gl-w-28');
      }

      return classList;
    },
    trialPopoverCategory() {
      return this.isTrialActive
        ? trackingEvents.activeTrialCategory
        : trackingEvents.trialEndedCategory;
    },
    handRaiseLeadBtnTracking() {
      const { action, label } = trackingEvents.contactSalesBtnClick;
      return {
        category: this.trialPopoverCategory,
        action,
        label,
      };
    },
  },
  created() {
    this.debouncedResize = debounce(() => this.updateDisabledState(), resizeEventDebounceMS);
    window.addEventListener(RESIZE_EVENT, this.debouncedResize);
  },
  mounted() {
    this.updateDisabledState();
  },
  beforeDestroy() {
    window.removeEventListener(RESIZE_EVENT, this.debouncedResize);
  },
  methods: {
    trackPageAction(eventName) {
      const { action, ...options } = trackingEvents[eventName];
      const category = this.trialPopoverCategory;

      this.track(action, { category, ...options });
    },
    updateDisabledState() {
      this.disabled = disabledBreakpoints.includes(bp.getBreakpointSize());
    },
    onShown() {
      this.trackPageAction('popoverShown');
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
    :delay="{ hide: 400 } /* eslint-disable-line @gitlab/vue-no-new-non-primitive-in-template */"
    :css-classes="cssClasses"
    data-testid="trial-status-popover"
    @shown="onShown"
  >
    <template #title>
      <div class="gl-text-size-h2">
        {{ popoverTitle }}
      </div>
    </template>

    <gl-sprintf v-if="isTrialActive" :message="popoverContent">
      <template #strong="{ content }">
        <strong>{{ content }}</strong>
      </template>
      <template #planName>{{ planNameWithoutTrial }}</template>
    </gl-sprintf>

    <div v-else>
      <p>{{ $options.i18n.popoverContentExpiredTrial }}</p>
    </div>

    <div class="gl-mt-5">
      <gl-button
        :href="plansHref"
        variant="confirm"
        size="small"
        class="gl-mb-3"
        block
        data-testid="compare-btn"
        :title="$options.i18n.compareAllButtonTitle"
        @click="trackPageAction('compareBtnClick')"
      >
        <span class="gl-text-sm">{{ $options.i18n.compareAllButtonTitle }}</span>
      </gl-button>

      <hand-raise-lead-button
        :button-attributes="$options.handRaiseLeadAttributes"
        :modal-id="$options.modalId"
        glm-content="trial-status-show-group"
        :cta-tracking="handRaiseLeadBtnTracking"
      />

      <gl-button
        :href="trialDiscoverPagePath"
        category="tertiary"
        variant="confirm"
        size="small"
        class="gl-mt-3"
        block
        data-testid="learn-about-features-btn"
        :title="$options.i18n.learnAboutButtonTitle"
        @click="trackPageAction('learnAboutFeaturesClick')"
      >
        <span class="gl-text-sm">{{ $options.i18n.learnAboutButtonTitle }}</span>
      </gl-button>
    </div>
  </gl-popover>
</template>
