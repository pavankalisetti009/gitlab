<script>
import { GlIcon, GlLink } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';

export default {
  name: 'PremiumPlanSection',

  components: {
    GlIcon,
    GlLink,
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
  },
};
</script>

<template>
  <div
    class="gl-border gl-flex-1 gl-rounded-b-lg gl-border-t-0 gl-bg-subtle gl-p-6 @md/panel:gl-border-t @md/panel:gl-rounded-l-none @md/panel:gl-rounded-r-lg @md/panel:gl-border-l-0"
  >
    <div class="gl-pb-6">
      <h3 class="gl-heading-3 gl-mb-1 gl-text-default">{{ s__('Billings|Premium') }}</h3>
      <p class="gl-font-weight-semibold gl-m-0 gl-text-default">
        {{ s__('Billings|$29 per user/month') }}
      </p>
    </div>

    <div class="gl-mb-5 gl-text-subtle">
      <p class="gl-mb-4 gl-text-md gl-font-normal">
        {{ s__('Billings|Everything from Free, plus:') }}
      </p>

      <div class="gl-list-style-none gl-p-0 gl-text-sm">
        <div class="gl-display-flex gl-align-items-start gl-mb-3">
          <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
          <span>{{ s__('Billings|AI Chat in the IDE') }}</span>
        </div>
        <div class="gl-display-flex gl-align-items-start gl-mb-3">
          <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
          <span>{{ s__('Billings|AI Code Suggestions in the IDE') }}</span>
        </div>
        <div class="gl-display-flex gl-align-items-start gl-mb-3">
          <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
          <span>{{ s__('Billings|Release Controls') }}</span>
        </div>
        <div class="gl-display-flex gl-align-items-start gl-mb-3">
          <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
          <span>{{ s__('Billings|Team Project Management') }}</span>
        </div>
        <div class="gl-display-flex gl-align-items-start gl-mb-3">
          <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
          <span>{{ s__('Billings|Priority Support') }}</span>
        </div>
        <div class="gl-display-flex gl-align-items-start gl-mb-3">
          <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
          <span>{{ s__('Billings|10,000 compute minutes per month') }}</span>
        </div>
        <div class="gl-display-flex gl-align-items-start gl-mb-3">
          <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
          <span>{{ s__('Billings|Unlimited licensed users') }}</span>
        </div>
      </div>
    </div>

    <gl-link
      :href="groupBillingHref"
      data-event-tracking="click_link_compare_plans"
      :data-event-property="groupId"
    >
      {{ s__('Billings|See all features and compare plans') }}
    </gl-link>
  </div>
</template>
