<script>
import { GlIcon, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';

export default {
  name: 'PolicyPopover',
  components: {
    GlIcon,
    GlLink,
    GlPopover,
    GlSprintf,
  },
  props: {
    content: {
      type: String,
      required: true,
    },
    iconName: {
      type: String,
      required: false,
      default: 'question-o',
    },
    href: {
      type: String,
      required: false,
      default: null,
    },
    target: {
      type: String,
      required: false,
      default: 'popover-icon',
    },
    title: {
      type: String,
      required: false,
      default: null,
    },
    showCloseButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    showPopover: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
};
</script>

<template>
  <div>
    <gl-popover
      v-if="showPopover"
      :target="target"
      :show-close-button="showCloseButton"
      :title="title"
    >
      <gl-sprintf :message="content">
        <template #link="{ content: linkContent }">
          <gl-link v-if="href" class="gl-text-sm" target="_blank" :href="href">{{
            linkContent
          }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-popover>

    <slot name="trigger">
      <gl-icon :id="target" class="gl-text-blue-600" :name="iconName" />
    </slot>
  </div>
</template>
