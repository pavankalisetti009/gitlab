<script>
import { GlTabs, GlTab } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import TempForm from './security_labels/temp_form.vue';

export default {
  components: {
    GlTabs,
    GlTab,
    PageHeading,
    TempForm,
  },
};
</script>
<template>
  <div>
    <page-heading :heading="s__('SecurityConfiguration|Security configuration')" />
    <gl-tabs>
      <gl-tab :title="s__('SecurityConfiguration|Security labels')">
        <p class="gl-my-5">
          {{
            s__(
              'SecurityConfiguration|Use security labels to classify projects by business context, security needs, and more. Categories are shared across your groups, enabling consistent and scalable classification of assets. These labels can help prioritize security efforts, filter dashboards, and apply consistent governance across projects.',
            )
          }}
        </p>
        <temp-form />
      </gl-tab>
    </gl-tabs>
  </div>
</template>
