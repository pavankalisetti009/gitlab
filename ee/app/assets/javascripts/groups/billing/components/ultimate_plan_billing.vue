<script>
import { GlIcon, GlPopover, GlSprintf, GlLink } from '@gitlab/ui';

export default {
  name: 'UltimatePlanBilling',
  components: {
    GlIcon,
    GlPopover,
    GlSprintf,
    GlLink,
  },
  props: {
    trialActive: {
      type: Boolean,
      required: true,
    },
    isNewTrialType: {
      type: Boolean,
      required: false,
      default: false,
    },
    creditsPopover: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <div class="gl-flex-1 gl-p-6 md:gl-border-l">
    <div class="gl-flex">
      <div class="gl-mr-1 gl-mt-3 gl-text-lg gl-font-bold">$</div>
      <div class="gl-mt-4 gl-text-size-h1-xl gl-font-bold md:gl-mt-0">{{ __('99') }}</div>
      <div class="gl-ml-3 gl-mt-3 gl-text-sm gl-text-subtle">
        <div>{{ s__('BillingPlans|per user/month,') }}</div>
        <div>{{ s__('BillingPlans|Billed annually at $1,188 USD') }}</div>
      </div>
    </div>

    <div class="gl-mt-7 gl-text-lg gl-font-bold">
      {{ s__('BillingPlans|Everything from Premium, plus:') }}
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Application Security Testing') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Software Supply Chain Security') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Vulnerability Management') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Strategic Portfolio Management') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Value Stream Management') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Governance & Compliance') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|50,000 compute minutes per month') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Unlimited guest users') }}</span>
    </div>

    <template v-if="isNewTrialType">
      <div class="gl-mt-6 gl-text-lg gl-font-bold md:gl-mt-4">
        {{ s__('BillingPlans|GitLab Duo Agent Platform:') }}
      </div>

      <div class="gl-mt-6 gl-flex md:gl-mt-4">
        <div>
          <gl-icon name="check" class="gl-mr-3 gl-mt-1 gl-text-feedback-info" />
        </div>

        <div data-testid="ultimate-gitlab-credits">
          <span v-if="trialActive" id="ultimate-gitlab-credits" class="gl-text-lg gl-underline">{{
            s__('BillingPlans|Includes $24 in GitLab Credits per user per month')
          }}</span>

          <span v-else id="ultimate-gitlab-credits" class="gl-text-lg gl-underline">{{
            s__('BillingPlans|$24 in GitLab Credits per user per month')
          }}</span>

          <gl-popover target="ultimate-gitlab-credits">
            <span>
              <gl-sprintf :message="creditsPopover.text">
                <template #link="{ content }">
                  <gl-link
                    class="!gl-text-default gl-underline"
                    target="_blank"
                    :href="creditsPopover.url"
                    >{{ content }}</gl-link
                  >
                </template>
              </gl-sprintf>
            </span>
          </gl-popover>
        </div>
      </div>
    </template>

    <div class="gl-mt-6 gl-text-lg gl-font-bold md:gl-mt-4">{{ s__('BillingPlans|Add-ons') }}</div>

    <div v-if="!isNewTrialType" class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Duo Enterprise') }}</span>
    </div>

    <div class="gl-mt-6 md:gl-mt-4">
      <gl-icon name="check" class="gl-mr-2 gl-mt-1 gl-text-feedback-info" />
      <span class="gl-text-lg">{{ s__('BillingPlans|Enterprise Agile Planning Seats') }}</span>
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
