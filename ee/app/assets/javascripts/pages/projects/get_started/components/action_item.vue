<script>
import { GlIcon, GlLink, GlTooltipDirective } from '@gitlab/ui';
import eventHub from '~/invite_members/event_hub';
import { LEARN_GITLAB } from 'ee/invite_members/constants';
import Tracking from '~/tracking';
import { ICON_TYPE_EMPTY, ICON_TYPE_PARTIAL, ICON_TYPE_COMPLETED } from '../constants';

export default {
  name: 'ActionItem',
  components: {
    GlIcon,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  emptyIcon: ICON_TYPE_EMPTY,
  partialIcon: ICON_TYPE_PARTIAL,
  completedIcon: ICON_TYPE_COMPLETED,
  urlType: 'invite',
  mixins: [Tracking.mixin({ category: 'projects:learn_gitlab:show' })],
  props: {
    action: {
      type: Object,
      required: true,
    },
  },
  computed: {
    iconName() {
      return this.action.completed ? this.$options.completedIcon : this.$options.emptyIcon;
    },

    isDisabled() {
      return this.action.enabled === false;
    },
  },
  methods: {
    handleActionClick() {
      if (this.action.urlType === this.$options.urlType) {
        eventHub.$emit('openModal', { source: LEARN_GITLAB });
      }

      this.track('click_link', { label: this.action.trackLabel });
    },
  },
};
</script>

<template>
  <li class="gl-flex gl-items-center gl-gap-3">
    <gl-icon variant="default" :name="iconName" data-testid="action-icon" />
    <span v-if="action.completed" class="gl-display-inline-block gl-line-through">
      {{ action.title }}
    </span>
    <gl-link
      v-else-if="!isDisabled"
      class="gl-display-inline-block"
      :href="action.url"
      @click="handleActionClick"
    >
      {{ action.title }}
    </gl-link>
    <span
      v-else
      class="gl-display-inline-block gl-text-subtle"
      aria-disabled="true"
      :aria-label="
        s__('GetStarted|You don\'t have sufficient access to perform this action: ') + action.title
      "
      data-testid="action-disabled"
    >
      {{ action.title }}
      <gl-icon
        v-gl-tooltip="s__('GetStarted|You don\'t have sufficient access to perform this action')"
        name="lock"
        class="gl-ml-2"
        aria-hidden="true"
        data-testid="disabled-icon"
      />
      <span class="gl-sr-only">
        {{ s__("GetStarted|You don't have sufficient access to perform this action") }}
      </span>
    </span>
  </li>
</template>
