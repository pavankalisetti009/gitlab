<script>
import { s__ } from '~/locale';

export default {
  name: 'TrialPlanSection',
  props: {
    isNewTrialType: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    trialHeaderText() {
      return this.isNewTrialType
        ? s__('Billings|Your group is on a trial of Gitlab Ultimate')
        : s__('Billings|Your group is on a trial of Ultimate + GitLab Duo Enterprise');
    },
  },
};
</script>

<template>
  <div>
    <h3 class="gl-heading-3 gl-text-default">
      {{ trialHeaderText }}
    </h3>

    <div class="gl-mb-5 gl-text-subtle">
      <div class="gl-list-style-none gl-p-0">
        <div class="gl-display-flex gl-align-items-start gl-mb-5 gl-text-subtle">
          <span>{{
            s__(
              'Billings|Your trial includes all the benefits of Ultimate, plus access to advanced AI features.',
            )
          }}</span>
        </div>
        <div class="gl-display-flex gl-align-items-start gl-text-subtle">
          <span>{{
            s__(
              'Billings|At the end of the trial, your subscription changes to Free. Upgrade to Premium to keep using advanced features.',
            )
          }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
