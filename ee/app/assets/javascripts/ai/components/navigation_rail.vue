<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'NavigationRail',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    duoChatLabel: __('GitLab Duo Chat'),
    suggestionsLabel: __('GitLab Duo Suggestions'),
    sessionsLabel: __('GitLab Duo Sessions'),
  },
  props: {
    activeTab: {
      type: String,
      required: true,
      default: null,
    },
    isExpanded: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  methods: {
    toggleTab(tab) {
      this.$emit('handleTabToggle', tab);
    },
  },
};
</script>
<template>
  <div
    class="gl-flex gl-w-[32px] gl-flex-col gl-gap-3 gl-bg-transparent gl-pt-3"
    role="tablist"
    aria-orientation="vertical"
  >
    <gl-button
      v-gl-tooltip.left
      icon="comment"
      class="!gl-rounded-lg"
      :class="['ai-nav-icon', { 'ai-nav-icon-active': activeTab === 'chat' }]"
      category="tertiary"
      :aria-selected="activeTab === 'chat'"
      :aria-expanded="isExpanded"
      :aria-label="$options.i18n.duoChatLabel"
      :title="$options.i18n.duoChatLabel"
      data-testid="ai-chat-toggle"
      @click="toggleTab('chat')"
    />
    <gl-button
      v-gl-tooltip.left
      icon="session-ai"
      class="!gl-rounded-lg"
      :class="['ai-nav-icon', { 'ai-nav-icon-active': activeTab === 'sessions' }]"
      category="tertiary"
      :aria-selected="activeTab === 'sessions'"
      :aria-expanded="isExpanded"
      :aria-label="$options.i18n.sessionsLabel"
      :title="$options.i18n.sessionsLabel"
      data-testid="ai-sessions-toggle"
      @click="toggleTab('sessions')"
    />
    <gl-button
      v-gl-tooltip.left
      icon="suggestion-ai"
      class="!gl-rounded-lg"
      :class="['ai-nav-icon', { 'ai-nav-icon-active': activeTab === 'suggestions' }]"
      category="tertiary"
      :aria-selected="activeTab === 'suggestions'"
      :aria-expanded="isExpanded"
      :aria-label="$options.i18n.suggestionsLabel"
      :title="$options.i18n.suggestionsLabel"
      data-testid="ai-suggestions-toggle"
      @click="toggleTab('suggestions')"
    />
  </div>
</template>
