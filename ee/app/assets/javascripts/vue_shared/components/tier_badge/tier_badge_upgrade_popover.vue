<script>
import { GlPopover, GlButton } from '@gitlab/ui';
import Tracking from '~/tracking';

export default {
  name: 'TierBadgePopover',
  components: {
    GlPopover,
    GlButton,
  },
  mixins: [Tracking.mixin({ label: 'tier_badge_upgrade' })],
  inject: ['primaryCtaLink'],
  props: {
    target: {
      type: HTMLElement,
      required: true,
    },
  },
  methods: {
    trackPrimaryCta() {
      this.track('click_start_trial_button');
    },
  },
};
</script>

<template>
  <gl-popover
    :title="s__('TierBadgePopover|Unlock advanced features')"
    :target="target"
    placement="bottom"
    show-close-button
  >
    <div class="gl-mb-3">
      {{
        s__(
          'TierBadgePopover|Get advanced features like GitLab Duo, merge approvals, epics, and code review analytics.',
        )
      }}
    </div>
    <gl-button
      :href="primaryCtaLink"
      class="gl-my-2 gl-w-full"
      variant="confirm"
      data-testid="tier-badge-popover-primary-cta"
      @click="trackPrimaryCta"
      >{{ s__('TierBadgePopover|Upgrade to unlock') }}</gl-button
    >
  </gl-popover>
</template>
