<script>
import { GlBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import Tracking from '~/tracking';
import TierBadgePopover from './tier_badge_popover.vue';
import TierBadgeUpgradePopover from './tier_badge_upgrade_popover.vue';

export default {
  components: {
    GlBadge,
    TierBadgePopover,
    TierBadgeUpgradePopover,
  },
  mixins: [Tracking.mixin({ label: 'tier_badge' })],
  props: {
    tier: {
      type: String,
      required: false,
      default: s__('TierBadge|Free'),
    },
    isUpgrade: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data: () => ({ target: undefined }),
  mounted() {
    this.trackRender();
    this.target = this.$refs.badge?.$el;
  },
  methods: {
    trackRender() {
      this.track('render_badge');
    },
    trackHover() {
      this.track('render_flyout');
    },
  },
};
</script>
<template>
  <span class="gl-ml-2 gl-flex gl-items-center" @mouseover="trackHover">
    <gl-badge ref="badge" data-testid="tier-badge" variant="tier">
      {{ tier }}
    </gl-badge>
    <template v-if="target">
      <tier-badge-upgrade-popover v-if="isUpgrade" :target="target" triggers="hover focus manual" />
      <tier-badge-popover v-else :target="target" triggers="hover focus manual" :tier="tier" />
    </template>
  </span>
</template>
