<script>
import { GlIcon } from '@gitlab/ui';

export default {
  name: 'PremiumPlanBilling',
  components: {
    GlIcon,
  },
};
</script>

<template>
  <div class="gl-flex-1 gl-p-6">
    <div class="gl-flex">
      <div class="gl-mr-1 gl-mt-3 gl-text-lg gl-font-bold">$</div>
      <div class="gl-mt-4 gl-text-size-h1-xl gl-font-bold md:gl-mt-0">{{ __('29') }}</div>
      <div class="gl-ml-3 gl-mt-3 gl-text-sm gl-text-subtle">
        <div>{{ s__('BillingPlans|per user/month,') }}</div>
        <div>{{ s__('BillingPlans|Billed annually at $348 USD') }}</div>
      </div>
    </div>

    <div class="gl-mt-7 gl-text-lg gl-font-bold">
      {{ s__('BillingPlans|Everything from Free, plus:') }}
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|AI Chat in the IDE') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|AI Code Suggestions in the IDE') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Release Controls') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Team Project Management') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Priority Support') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|10,000 compute minutes per month') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Unlimited licensed users') }}</span>
    </div>

    <div class="gl-mt-6 gl-text-lg gl-font-bold md:gl-mt-4">{{ s__('BillingPlans|Add-ons') }}</div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Duo Pro') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Duo Enterprise') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Compute Minutes') }}</span>
    </div>

    <div class="gl-mb-3 gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Storage') }}</span>
    </div>
  </div>
</template>
