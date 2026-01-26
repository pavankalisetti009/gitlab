<script>
import { GlButton } from '@gitlab/ui';
import tanukiAiSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';

export default {
  name: 'NoNamespaceEmptyState',
  components: {
    GlButton,
  },
  props: {
    preferencesPath: {
      type: String,
      required: false,
      default: '',
    },
    isClassicAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['return-to-classic'],
  tanukiAiSvgUrl,
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4 gl-py-8"
    data-testid="no-namespace-empty-state"
  >
    <img
      :src="$options.tanukiAiSvgUrl"
      class="gl-h-10 gl-w-10"
      :alt="s__('DuoAgenticChat|GitLab Duo AI assistant')"
    />
    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgenticChat|GitLab Duo Agentic Chat is unavailable') }}
    </h2>
    <p class="gl-text-subtle">
      {{
        s__(
          'DuoAgenticChat|To use Agentic Chat, select a default namespace in your user profile preferences. Alternatively, turn off the Agentic toggle to return to Classic Chat.',
        )
      }}
    </p>
    <div class="gl-flex gl-gap-2">
      <gl-button
        v-if="preferencesPath"
        variant="confirm"
        category="primary"
        :href="preferencesPath"
        target="_blank"
        data-testid="go-to-preferences-button"
      >
        {{ s__('DuoAgenticChat|Select default namespace') }}
      </gl-button>
      <gl-button
        v-if="isClassicAvailable"
        variant="default"
        category="primary"
        @click="$emit('return-to-classic')"
      >
        {{ s__('DuoAgenticChat|Return to Classic Chat') }}
      </gl-button>
    </div>
  </div>
</template>
