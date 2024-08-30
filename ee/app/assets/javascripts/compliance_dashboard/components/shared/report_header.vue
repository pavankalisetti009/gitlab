<script>
import { GlLink } from '@gitlab/ui';

import { __ } from '~/locale';

export default {
  name: 'ReportHeader',
  components: {
    GlLink,
  },
  props: {
    heading: {
      type: String,
      required: true,
    },
    subheading: {
      type: String,
      required: true,
    },
    documentationPath: {
      type: String,
      required: true,
    },
  },
  i18n: {
    learnMore: __('Learn more.'),
  },
};
</script>
<template>
  <header class="gl-my-6 gl-mr-3 gl-flex gl-flex-col gl-justify-between lg:gl-flex-row">
    <div>
      <h1 class="gl-heading-1 gl-my-0 gl-grow" data-testid="heading">{{ heading }}</h1>
      <p class="gl-mt-5" data-testid="subheading">
        {{ subheading }}
        <gl-link :href="documentationPath">{{ $options.i18n.learnMore }}</gl-link>
      </p>
    </div>
    <div>
      <slot name="actions"></slot>
    </div>
  </header>
</template>
