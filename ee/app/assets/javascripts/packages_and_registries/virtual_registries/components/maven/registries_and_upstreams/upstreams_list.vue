<script>
import { GlEmptyState } from '@gitlab/ui';
import emptyStateIllustrationUrl from '@gitlab/svgs/dist/illustrations/empty-state/empty-radar-md.svg?url';

export default {
  name: 'MavenUpstreamsList',
  components: {
    GlEmptyState,
  },
  data() {
    return {
      mavenUpstreams: [],
    };
  },
  created() {
    // To be updated as per https://gitlab.com/gitlab-org/gitlab/-/issues/556837
    this.$emit('updateCount', this.mavenUpstreams.length);
  },
  emptyStateIllustrationUrl,
};
</script>

<template>
  <gl-empty-state
    :svg-path="$options.emptyStateIllustrationUrl"
    :title="s__('VirtualRegistry|Connect Maven virtual registry to an upstream')"
    :description="
      s__(
        'VirtualRegistry|Configure an upstream registry to manage Maven artifacts and cache entries.',
      )
    "
  />
</template>
