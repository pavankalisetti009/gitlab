<script>
import { GlSprintf, GlLink, GlCard, GlButton } from '@gitlab/ui';
import { PROMO_URL, isAbsolute, joinPaths } from '~/lib/utils/url_utility';

export default {
  name: 'OverageOptInCard',
  components: {
    GlSprintf,
    GlLink,
    GlCard,
    GlButton,
  },
  props: {
    customersUsageDashboardPath: {
      type: String,
      required: true,
    },
  },
  computed: {
    customersUsageDashboardUrl() {
      if (isAbsolute(this.customersUsageDashboardPath)) return this.customersUsageDashboardPath;

      return joinPaths(gon.subscriptions_url, this.customersUsageDashboardPath);
    },
  },
  overageDocsLink: `${PROMO_URL}/pricing`,
};
</script>
<template>
  <gl-card class="gl-banner gl-flex-1 gl-py-6 gl-pl-6 gl-pr-8" body-class="!gl-p-0">
    <h2 class="mt-0 mb-2 gl-heading-3">
      {{ s__("UsageBilling|Keep your team's GitLab Duo features unblocked") }}
    </h2>
    <p>
      <gl-sprintf
        :message="
          s__(
            'UsageBilling|Enable on-demand billing to keep GitLab Duo features active when monthly GitLab Credits run out. Without these terms, users lose GitLab Duo access after exhausting their included GitLab Credits. Learn about %{linkStart}overage billing%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.overageDocsLink">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
    <gl-button :href="customersUsageDashboardUrl" variant="confirm">
      {{ s__('UsageBilling|Enable on-demand billing') }}
    </gl-button>
  </gl-card>
</template>
