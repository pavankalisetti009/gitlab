<script>
import { GlSprintf, GlLink } from '@gitlab/ui';

export default {
  components: {
    GlLink,
    GlSprintf,
  },
  props: {
    message: {
      type: String,
      required: true,
    },
    linkObject: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <gl-sprintf :message="message">
      <template v-for="(href, name) in linkObject" #[name]="{ content }">
        <gl-link :key="name" class="!gl-no-underline" :href="href" target="_blank">{{
          content
        }}</gl-link>
      </template>
    </gl-sprintf>
  </div>
</template>
