<script>
import { GlButton } from '@gitlab/ui';
import tanukiAiSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, sprintf } from '~/locale';

export default {
  name: 'NoCreditsEmptyState',
  components: {
    GlButton,
  },
  directives: {
    SafeHtml,
  },
  props: {
    isClassicAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['return-to-classic'],
  creditsExhaustedEmptyStateDescription() {
    const docsUrl = helpPagePath('user/gitlab_duo_chat/_index');
    const linkStart = `<a href="${docsUrl}" class="gl-link" target="_blank" rel="noopener noreferrer">`;
    const linkEnd = '</a>';

    return sprintf(
      s__(
        'DuoAgenticChat|No credits remain for this billing period. To continue collaborating with GitLab Duo, turn off the Agentic mode toggle. You can still get AI assistance, just without the advanced agentic features. %{linkStart}Learn more%{linkEnd}.',
      ),
      { linkStart, linkEnd },
      false,
    );
  },
  tanukiAiSvgUrl,
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4 gl-py-8"
    data-testid="no-credits-empty-state"
  >
    <img
      :src="$options.tanukiAiSvgUrl"
      class="gl-h-10 gl-w-10"
      :alt="s__('DuoAgenticChat|GitLab Duo AI assistant')"
    />
    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgenticChat|No GitLab Credits remain') }}
    </h2>
    <p v-safe-html="$options.creditsExhaustedEmptyStateDescription()" class="gl-text-subtle"></p>
    <p class="gl-mb-0 gl-text-sm gl-text-subtle">
      {{ s__('DuoAgenticChat|Need more credits? Contact your administrator.') }}
    </p>
    <gl-button
      v-if="isClassicAvailable"
      variant="confirm"
      category="primary"
      @click="$emit('return-to-classic')"
    >
      {{ s__('DuoAgenticChat|Turn off Agentic mode') }}
    </gl-button>
  </div>
</template>
