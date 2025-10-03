<script>
import { GlButton } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';

export default {
  name: 'CurrentPlanHeader',
  components: {
    GlButton,
  },
  props: {
    seatsInUse: {
      type: Number,
      required: true,
    },
    trialActive: {
      type: Boolean,
      required: true,
    },
    manageSeatsPath: {
      type: String,
      required: true,
    },
    totalSeats: {
      type: Number,
      required: false,
      default: 0,
    },
    trialEndsOn: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    header() {
      const planName = this.trialActive
        ? s__('BillingPlans|a trial of Ultimate + Duo Enterprise')
        : s__('BillingPlans|GitLab Free');

      return sprintf(s__('BillingPlans|Your group is on %{planName}'), { planName });
    },
    seats() {
      if (this.trialActive) {
        return this.seatsInUse;
      }

      return `${this.seatsInUse}/${this.totalSeats || __('Unlimited')}`;
    },
  },
};
</script>

<template>
  <div
    class="gl-border gl-flex gl-flex-1 gl-flex-col gl-justify-between gl-rounded-t-lg gl-bg-default gl-p-6 md:gl-rounded-l-lg md:gl-rounded-r-none"
  >
    <div>
      <h3 class="gl-heading-3-fixed gl-mb-3 gl-text-default">
        {{ header }}
      </h3>

      <div v-if="trialActive" class="gl-text-sm gl-text-subtle">
        {{ s__('BillingPlans|This trial ends on') }}
        <span class="gl-font-bold">{{ trialEndsOn }}</span>
      </div>

      <div class="gl-mt-5 gl-text-lg">
        <span class="gl-mr-3 gl-text-size-h1 gl-font-bold" data-testid="seats-in-use">{{
          seats
        }}</span>

        <span class="gl-text-subtle">{{ s__('BillingPlans|Seats in use') }}</span>
      </div>
    </div>

    <div class="gl-mt-5 gl-flex-row">
      <gl-button
        category="secondary"
        data-track-action="click_button"
        data-track-label="manage_seats"
        :href="manageSeatsPath"
        >{{ s__('BillingPlans|Manage seats') }}</gl-button
      >
    </div>
  </div>
</template>
