<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { BV_HIDE_TOOLTIP } from '~/lib/utils/constants';
import { keysFor, DUO_CHAT } from '~/behaviors/shortcuts/keybindings';
import { shouldDisableShortcuts } from '~/behaviors/shortcuts/shortcuts_toggle';
import { __ } from '~/locale';
import { sanitize } from '~/lib/dompurify';

export default {
  name: 'NavigationRail',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    duoChatLabel: __('Active GitLab Duo Chat'),
    newLabel: __('New GitLab Duo Chat'),
    historyLabel: __('GitLab Duo Chat history'),
    suggestionsLabel: __('GitLab Duo suggestions'),
    sessionsLabel: __('GitLab Duo sessions'),
  },
  props: {
    activeTab: {
      type: String,
      required: false,
      default: null,
    },
    isExpanded: {
      type: Boolean,
      required: false,
      default: true,
    },
    showSuggestionsTab: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    duoShortcutKey() {
      return shouldDisableShortcuts() ? null : keysFor(DUO_CHAT);
    },
    formattedDuoShortcutTooltip() {
      const description = this.$options.i18n.duoChatLabel;
      const key = keysFor(DUO_CHAT);
      return shouldDisableShortcuts()
        ? description
        : sanitize(`${description} <kbd class="flat gl-ml-1" aria-hidden=true>${key}</kbd>`);
    },
  },
  methods: {
    toggleTab(tab) {
      this.$emit('handleTabToggle', tab);
    },
    hideTooltips() {
      this.$root.$emit(BV_HIDE_TOOLTIP);
    },
  },
};
</script>

<!-- eslint-disable @gitlab/vue-tailwind-no-max-width-media-queries -->
<template>
  <div
    class="gl-ml-3 gl-flex gl-items-center gl-gap-3 gl-bg-transparent max-lg:gl-h-[var(--ai-navigation-rail-size)] max-lg:gl-flex-1 max-lg:gl-px-3 max-sm:gl-px-0 lg:gl-ml-0 lg:gl-w-[var(--ai-navigation-rail-size)] lg:gl-flex-col lg:gl-py-3"
    role="tablist"
    aria-orientation="vertical"
  >
    <gl-button
      v-gl-tooltip.left="{
        title: formattedDuoShortcutTooltip,
        html: true,
      }"
      icon="comment"
      class="js-tanuki-bot-chat-toggle !gl-rounded-lg"
      :class="['ai-nav-icon', { 'ai-nav-icon-active': activeTab === 'chat' }]"
      category="tertiary"
      :aria-selected="activeTab === 'chat'"
      :aria-expanded="isExpanded"
      :aria-keyshortcuts="duoShortcutKey"
      :aria-label="$options.i18n.duoChatLabel"
      data-testid="ai-chat-toggle"
      @mouseout="hideTooltips"
      @click="toggleTab('chat')"
    />
    <gl-button
      v-gl-tooltip.left
      icon="plus"
      class="!gl-rounded-lg"
      :class="['ai-nav-icon', { 'ai-nav-icon-active': activeTab === 'new' }]"
      category="tertiary"
      :aria-selected="activeTab === 'new'"
      :aria-expanded="isExpanded"
      :aria-label="$options.i18n.newLabel"
      :title="$options.i18n.newLabel"
      data-testid="ai-new-toggle"
      @mouseout="hideTooltips"
      @click="toggleTab('new')"
    />
    <gl-button
      v-gl-tooltip.left
      icon="history"
      class="!gl-rounded-lg"
      :class="['ai-nav-icon', { 'ai-nav-icon-active': activeTab === 'history' }]"
      category="tertiary"
      :aria-selected="activeTab === 'history'"
      :aria-expanded="isExpanded"
      :aria-label="$options.i18n.historyLabel"
      :title="$options.i18n.historyLabel"
      data-testid="ai-history-toggle"
      @mouseout="hideTooltips"
      @click="toggleTab('history')"
    />
    <div
      class="gl-my-4 gl-h-5 gl-w-1 gl-border-0 gl-border-r-1 gl-border-solid gl-border-[#7759C233] lg:gl-mx-auto lg:gl-h-1 lg:gl-w-5 lg:gl-border-r-0 lg:gl-border-t-1"
      name="divider"
    ></div>
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
      @mouseout="hideTooltips"
      @click="toggleTab('sessions')"
    />
    <gl-button
      v-if="showSuggestionsTab"
      v-gl-tooltip.left
      icon="suggestion-ai"
      class="!gl-rounded-lg max-lg:gl-ml-auto lg:gl-mt-auto"
      :class="['ai-nav-icon', { 'ai-nav-icon-active': activeTab === 'suggestions' }]"
      category="tertiary"
      :aria-selected="activeTab === 'suggestions'"
      :aria-expanded="isExpanded"
      :aria-label="$options.i18n.suggestionsLabel"
      :title="$options.i18n.suggestionsLabel"
      data-testid="ai-suggestions-toggle"
      @mouseout="hideTooltips"
      @click="toggleTab('suggestions')"
    />
  </div>
</template>
