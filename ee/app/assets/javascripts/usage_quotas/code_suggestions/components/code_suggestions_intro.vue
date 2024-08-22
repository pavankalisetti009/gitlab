<script>
import {
  GlEmptyState,
  GlLink,
  GlSprintf,
  GlButton,
  GlIntersectionObserver,
  GlAlert,
} from '@gitlab/ui';
import emptyStateSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { __, s__ } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import {
  codeSuggestionsLearnMoreLink,
  VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD,
} from 'ee/usage_quotas/code_suggestions/constants';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import apolloProvider from 'ee/subscriptions/buy_addons_shared/graphql';
import Tracking, { InternalEvents } from '~/tracking';

export default {
  name: 'CodeSuggestionsIntro',
  helpLinks: {
    codeSuggestionsLearnMoreLink,
  },
  i18n: {
    purchaseSeats: __('Purchase seats'),
    buySubscription: __('Buy subscription'),
    trial: __('Start a trial'),
    description: s__(
      `CodeSuggestions|Enhance your coding experience with intelligent recommendations. %{linkStart}GitLab Duo%{linkEnd} offers features that use generative AI to suggest code.`,
    ),
    postTrialForFreeNamespaceDescription: s__(
      "CodeSuggestions|Before you can buy GitLab Duo seats, you'll need a Premium or Ultimate subscription.",
    ),
    postTrialAlertTitle: s__('CodeSuggestions|Your GitLab Duo Pro trial has expired'),
    postTrialAlertBody: s__(
      "CodeSuggestions|To buy GitLab Duo seats and regain access, you'll need a Premium or Ultimate subscription.",
    ),
    title: s__('CodeSuggestions|Introducing GitLab Duo'),
  },
  directives: {
    SafeHtml,
  },
  components: {
    HandRaiseLeadButton,
    GlEmptyState,
    GlLink,
    GlSprintf,
    GlButton,
    GlIntersectionObserver,
    GlAlert,
  },
  mixins: [Tracking.mixin(), InternalEvents.mixin()],
  inject: {
    duoProTrialHref: { default: null },
    addDuoProHref: { default: null },
    handRaiseLeadData: { default: {} },
    isFreeNamespace: { default: false },
    duoProActiveTrialEndDate: { default: null },
    buySubscriptionPath: { default: null },
    isStandalonePage: { default: false },
  },
  data() {
    return {
      isAlertDismissed: false,
    };
  },
  computed: {
    purchaseSeatsBtnCategory() {
      return this.duoProTrialHref ? 'secondary' : 'primary';
    },
    showPostTrialForFreeNamespace() {
      return this.isFreeNamespace && !this.duoProActiveTrialEndDate;
    },
  },
  mounted() {
    this.trackEvent(VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD);
  },
  methods: {
    trackPageView() {
      if (this.duoProTrialHref) {
        this.track('pageview', { label: 'duo_pro_add_on_tab_pre_trial' });
      } else if (this.showPostTrialForFreeNamespace) {
        this.track('pageview', { label: 'duo_pro_add_on_tab_expired_trial' });
      }
    },
    trackTrialClick() {
      this.track('click_button', { label: 'duo_pro_start_trial' });
    },
    trackPurchaseSeatsClick() {
      this.track('click_button', { label: 'duo_pro_purchase_seats' });
    },
    trackLearnMoreClick() {
      this.track('click_link', { label: 'duo_pro_marketing_page' });
    },
    trackBuySubscription() {
      this.track('click_button', { label: 'duo_pro_buy_subscription' });
    },
  },
  apolloProvider,
  emptyStateSvgUrl,
};
</script>
<template>
  <gl-intersection-observer @appear="trackPageView">
    <gl-alert
      v-if="showPostTrialForFreeNamespace && !isAlertDismissed"
      class="gl-mb-9"
      :class="{ '-gl-mt-3': !isStandalonePage }"
      variant="danger"
      :title="$options.i18n.postTrialAlertTitle"
      data-testid="duo-pro-post-trial-alert"
      @dismiss="isAlertDismissed = true"
    >
      {{ $options.i18n.postTrialAlertBody }}
    </gl-alert>
    <gl-empty-state :svg-path="$options.emptyStateSvgUrl" :svg-height="72">
      <template #title>
        <h1 class="gl-text-size-h-display gl-leading-36 h4">{{ $options.i18n.title }}</h1>
      </template>
      <template #description>
        <p v-if="showPostTrialForFreeNamespace" class="gl-max-w-48">
          {{ $options.i18n.postTrialForFreeNamespaceDescription }}
        </p>

        <gl-sprintf v-else :message="$options.i18n.description">
          <template #link="{ content }">
            <gl-link
              :href="$options.helpLinks.codeSuggestionsLearnMoreLink"
              target="_blank"
              class="gl-underline"
              data-testid="duo-pro-learn-more-link"
              @click="trackLearnMoreClick"
            >
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </template>
      <template #actions>
        <gl-button
          v-if="duoProTrialHref"
          :href="duoProTrialHref"
          variant="confirm"
          category="primary"
          class="sm:gl-w-auto gl-w-full"
          data-testid="duo-pro-start-trial-btn"
          @click="trackTrialClick"
        >
          {{ $options.i18n.trial }}
        </gl-button>
        <gl-button
          v-if="showPostTrialForFreeNamespace"
          :href="buySubscriptionPath"
          variant="confirm"
          class="sm:gl-w-auto gl-w-full"
          data-testid="duo-pro-buy-subscription-btn"
          @click="trackBuySubscription"
        >
          {{ $options.i18n.buySubscription }}
        </gl-button>
        <gl-button
          v-else
          :href="addDuoProHref"
          variant="confirm"
          :category="purchaseSeatsBtnCategory"
          class="sm:gl-w-auto gl-w-full sm:gl-ml-3 sm:gl-mt-0 gl-mt-3"
          data-testid="duo-pro-purchase-seats-btn"
          @click="trackPurchaseSeatsClick"
        >
          {{ $options.i18n.purchaseSeats }}
        </gl-button>
        <hand-raise-lead-button
          :button-attributes="handRaiseLeadData.buttonAttributes"
          :glm-content="handRaiseLeadData.glmContent"
          :product-interaction="handRaiseLeadData.productInteraction"
          :cta-tracking="handRaiseLeadData.ctaTracking"
        />
      </template>
    </gl-empty-state>
  </gl-intersection-observer>
</template>
