<script>
import { GlIcon } from '@gitlab/ui';

export default {
  name: 'FreePlanBilling',
  components: {
    GlIcon,
  },
};
</script>

<template>
  <div class="gl-p-6">
    <div class="gl-flex">
      <div class="gl-mr-1 gl-mt-3 gl-text-lg gl-font-bold">$</div>
      <div class="gl-mt-4 gl-text-size-h1-xl gl-font-bold md:gl-mt-0">{{ __('0') }}</div>
      <div class="gl-ml-3 gl-mt-3 gl-text-sm gl-text-subtle">
        <div>{{ s__('BillingPlans|per user/month,') }}</div>
        <div>{{ s__('BillingPlans|no credit card required') }}</div>
      </div>
    </div>

    <div class="gl-mt-7 gl-text-lg gl-font-bold">{{ s__('BillingPlans|Features include:') }}</div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Source Code Management & CI/CD') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|5 users per top-level group') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|400 compute minutes per month') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|10 GiB adjustable storage') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Static Application Security Testing') }}</span>
    </div>

    <div class="gl-mt-6 gl-text-lg gl-font-bold md:gl-mt-4">{{ s__('BillingPlans|Add-ons') }}</div>

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
