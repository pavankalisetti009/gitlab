<script>
import { GlIcon, GlButton, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import { focusDuoChatInput } from 'ee/ai/utils';
import { TRIAL_ACTIVE_FEATURE_HIGHLIGHTS } from 'ee/groups/billing/components/constants';

export default {
  name: 'TrialUpgradeSection',
  components: {
    GlIcon,
    GlButton,
    GlPopover,
    GlLink,
    GlSprintf,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    groupId: {
      type: Number,
      required: true,
    },
    groupBillingHref: {
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
  TRIAL_ACTIVE_FEATURE_HIGHLIGHTS,
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-y-5">
    <h3 class="gl-heading-3 gl-m-0 gl-text-default">
      {{ $options.TRIAL_ACTIVE_FEATURE_HIGHLIGHTS.header }}
    </h3>
    <p class="gl-font-weight-semibold gl-m-0 gl-text-subtle">
      {{ $options.TRIAL_ACTIVE_FEATURE_HIGHLIGHTS.subheader }}
    </p>

    <div>
      <ul class="gl-mb-4 gl-flex gl-list-none gl-flex-col gl-gap-y-4 gl-p-0">
        <li
          v-for="feature in $options.TRIAL_ACTIVE_FEATURE_HIGHLIGHTS.features"
          :key="feature.id"
          class="gl-flex gl-items-center gl-gap-3"
          data-testid="feature-highlight"
        >
          <div :id="feature.id">
            <gl-icon :name="feature.iconName" class="gl-mr-2 gl-mt-1" :variant="feature.variant" />
            <span class="gl-text-base gl-underline">{{ feature.title }}</span>
          </div>

          <gl-popover
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
        </li>
      </ul>
      <gl-link
        :href="groupBillingHref"
        data-event-tracking="click_link_compare_plans"
        :data-event-property="groupId"
        data-testid="compare-plans-link"
      >
        {{ s__('Billings|See all features and compare plans') }}
      </gl-link>
    </div>

    <p class="gl-m-0 gl-text-subtle">
      {{
        s__('Billings|Upgrade before your trial ends to maintain access to these Premium features.')
      }}
    </p>
  </div>
</template>
