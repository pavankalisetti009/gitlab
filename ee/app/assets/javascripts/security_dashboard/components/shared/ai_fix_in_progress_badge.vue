<script>
import { GlBadge, GlIcon, GlAnimatedLoaderIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'AiFixInProgressBadge',
  components: {
    GlAnimatedLoaderIcon,
    GlBadge,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    badgeText: s__('Vulnerability|AI Generating Fix'),
    tooltipText: s__('Vulnerability|AI is currently working to resolve this vulnerability'),
  },
};
</script>

<template>
  <gl-badge
    v-gl-tooltip
    :title="$options.i18n.tooltipText"
    variant="info"
    size="sm"
    data-testid="ai-fix-in-progress-badge"
  >
    <gl-icon name="tanuki-ai" class="gl-mr-1" />
    <span data-testid="ai-fix-in-progress-badge-text">
      {{ $options.i18n.badgeText }}
    </span>
    <span data-testid="ai-fix-in-progress-badge-tooltip" class="gl-sr-only">
      {{ $options.i18n.tooltipText }}
    </span>
    <gl-animated-loader-icon is-on class="gl-pt-2" />
  </gl-badge>
</template>
