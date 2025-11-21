<script>
import { GlIcon, GlButton, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import { focusDuoChatInput } from 'ee/ai/utils';
import { FEATURE_HIGHLIGHTS } from './constants';

const trackingMixin = InternalEvents.mixin();

export default {
  name: 'PremiumPlanHeader',
  components: {
    GlIcon,
    GlButton,
    GlLink,
    GlPopover,
    GlSprintf,
  },
  mixins: [trackingMixin],
  props: {
    trialActive: {
      type: Boolean,
      required: true,
    },
    trialExpired: {
      type: Boolean,
      required: true,
    },
    startTrialPath: {
      type: String,
      required: true,
    },
    upgradeToPremiumUrl: {
      type: String,
      required: true,
    },
    canAccessDuoChat: {
      type: Boolean,
      required: true,
    },
    exploreLinks: {
      type: Object,
      required: true,
    },
  },
  computed: {
    attributes() {
      if (this.trialActive) {
        return {
          ...FEATURE_HIGHLIGHTS.trialActive,
          postScript: s__(
            'BillingPlans|Upgrade before your trial ends to maintain access to these Premium features.',
          ),
          ctaHref: this.upgradeToPremiumUrl,
          ctaTrackingData: {
            'data-track-action': 'click_button',
            'data-track-label': 'plan_cta',
            'data-track-property': 'premium',
          },
        };
      }

      if (this.trialExpired) {
        return {
          ...FEATURE_HIGHLIGHTS.trialExpired,
          ctaHref: this.upgradeToPremiumUrl,
          ctaTrackingData: {
            'data-track-action': 'click_button',
            'data-track-label': 'plan_cta',
            'data-track-property': 'premium',
          },
        };
      }

      return {
        ...FEATURE_HIGHLIGHTS.notInTrial,
        ctaHref: this.startTrialPath,
        ctaTrackingData: {
          'data-event-tracking': 'click_duo_enterprise_trial_billing_page',
          'data-event-label': 'ultimate_and_duo_enterprise_trial',
        },
      };
    },
  },
  methods: {
    handleExploreLinkClick(id) {
      if (id === 'duoChat' && this.canAccessDuoChat) {
        focusDuoChatInput();
      }

      this.trackEvent('click_cta_premium_feature_popover_on_billings', {
        property: id,
      });
    },
    handlePopoverHover(id) {
      this.trackEvent('render_premium_feature_popover_on_billings', {
        property: id,
      });
    },
    featureButtonText(feature) {
      return sprintf(s__('BillingPlans|Explore %{feature}'), { feature });
    },
  },
};
</script>

<template>
  <div
    class="gl-border gl-flex-1 gl-rounded-b-lg gl-border-t-0 gl-bg-subtle gl-p-6 md:gl-border-t md:gl-rounded-l-none md:gl-rounded-r-lg md:gl-border-l-0"
  >
    <div>
      <h3 class="gl-heading-3-fixed gl-mb-3 gl-text-default">
        {{ attributes.header }}
      </h3>

      <div class="gl-text-sm gl-text-subtle">
        {{ attributes.subheader }}
      </div>

      <div
        :class="{
          'gl-mb-3 gl-mt-3 gl-grid gl-grid-flow-col gl-grid-cols-2 gl-grid-rows-3': trialActive,
        }"
      >
        <div v-for="feature in attributes.features" :key="feature.id" class="gl-mb-3 gl-mt-3">
          <div :id="feature.id">
            <gl-icon :name="feature.iconName" class="gl-mr-2 gl-mt-1" :variant="feature.variant" />
            <span :class="trialActive ? 'gl-text-base gl-underline' : 'gl-text-sm'">{{
              feature.title
            }}</span>
          </div>
          <gl-popover
            v-if="trialActive"
            :target="feature.id"
            :title="feature.title"
            show-close-button
            @shown="handlePopoverHover(feature.id)"
          >
            <gl-sprintf :message="feature.description">
              <template #learnMoreLink="{ content }">
                <gl-link :href="feature.docsLink" target="_blank">
                  {{ content }}
                </gl-link>
              </template>
            </gl-sprintf>

            <gl-button
              v-if="exploreLinks[feature.id] || feature.id === 'duoChat'"
              class="gl-mt-3 gl-w-full"
              :href="exploreLinks[feature.id]"
              variant="confirm"
              @click="handleExploreLinkClick(feature.id)"
            >
              {{ featureButtonText(feature.title) }}
            </gl-button>
          </gl-popover>
        </div>
      </div>

      <div v-if="attributes.postScript" class="gl-text-sm gl-text-subtle">
        {{ attributes.postScript }}
      </div>
    </div>

    <div class="gl-mt-5 gl-flex-row">
      <gl-button
        data-testid="upgrade-link-cta"
        :class="{ 'gl-w-full': trialActive }"
        :category="trialActive ? 'primary' : 'secondary'"
        :variant="trialActive ? 'confirm' : 'default'"
        v-bind="attributes.ctaTrackingData"
        :href="attributes.ctaHref"
        referrerpolicy="no-referrer-when-downgrade"
      >
        {{ attributes.ctaLabel }}
      </gl-button>
    </div>
  </div>
</template>
