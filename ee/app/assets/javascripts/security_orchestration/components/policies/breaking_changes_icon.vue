<script>
import { GlIcon, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    title: s__('SecurityOrchestration|Policy is invalid'),
  },
  name: 'BreakingChangesIcon',
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
    link: {
      type: String,
      required: false,
      default: '',
    },
    id: {
      type: String,
      required: false,
      default: '',
    },
  },
};
</script>

<template>
  <div>
    <gl-popover :title="$options.i18n.title" :target="id" show-close-button>
      <gl-sprintf :message="content">
        <template #link="{ content: linkContent }">
          <gl-link :href="link" target="_blank">{{ linkContent }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-popover>
    <gl-icon :id="id" class="gl-text-orange-600" name="warning" />
  </div>
</template>
