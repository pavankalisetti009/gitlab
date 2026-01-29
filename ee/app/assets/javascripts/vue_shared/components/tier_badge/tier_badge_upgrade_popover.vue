<script>
import { GlPopover, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import Tracking from '~/tracking';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  name: 'TierBadgeUpgradePopover',
  components: {
    GlPopover,
    GlButton,
  },
  mixins: [Tracking.mixin({ label: 'tier_badge_upgrade' }), glFeatureFlagsMixin()],
  inject: ['primaryCtaLink'],
  props: {
    target: {
      type: HTMLElement,
      required: true,
    },
  },
  computed: {
    popoverDescription() {
      return this.glFeatures.ultimateTrialWithDap
        ? s__(
            'TierBadgePopover|Get advanced features like GitLab Duo Agent Platform, merge approvals, epics, and code review analytics.',
          )
        : s__(
            'TierBadgePopover|Get advanced features like merge approvals, epics, and code review analytics.',
          );
    },
  },
  methods: {
    trackPrimaryCta() {
      this.track('click_upgrade_button');
    },
    trackPopoverClose() {
      this.track('close');
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
    @close-button-clicked="trackPopoverClose"
  >
    <div class="gl-mb-3">
      {{ popoverDescription }}
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
