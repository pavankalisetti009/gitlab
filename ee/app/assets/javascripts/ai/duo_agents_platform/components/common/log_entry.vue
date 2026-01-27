<script>
import { GlCollapse, GlButton } from '@gitlab/ui';
import { MessageToolKvSection } from '@gitlab/duo-ui';
import { s__ } from '~/locale';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { getMessageData } from 'ee/ai/duo_agents_platform/utils';
import NonGfmMarkdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'LogEntry',
  components: {
    GlCollapse,
    GlButton,
    MessageToolKvSection,
    NonGfmMarkdown,
    TimeAgoTooltip,
  },
  props: {
    item: {
      type: Object,
      required: true,
      validator(item) {
        return (
          typeof item === 'object' &&
          item.content &&
          item.messageType &&
          item.status &&
          item.timestamp
        );
      },
    },
    index: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      visible: false,
    };
  },
  computed: {
    toolInfo() {
      if (!this.item.toolInfo) {
        return null;
      }
      try {
        return JSON.parse(this.item.toolInfo);
      } catch (e) {
        captureException(e);
        return null;
      }
    },
    filePath() {
      return this.toolInfo?.args?.file_path;
    },
    title() {
      if (this.index === 0) {
        return s__('DuoAgentPlatform|Session triggered');
      }
      return getMessageData(this.item)?.title;
    },
    isMarkdown() {
      return this.item.messageType !== 'user' && this.index > 0;
    },
    collapseIcon() {
      return this.visible ? 'chevron-down' : 'chevron-right';
    },
  },
};
</script>
<template>
  <div class="gl-w-full">
    <div class="gl-flex gl-justify-between">
      <strong class="gl-mb-1 gl-text-strong" data-testid="log-entry-title">{{ title }}</strong>

      <time-ago-tooltip
        :time="item.timestamp"
        css-class="gl-text-subtle"
        data-testid="log-entry-timestamp"
      />
    </div>

    <div class="gl-mb-1 gl-flex gl-items-start gl-justify-between gl-gap-2">
      <div>
        <non-gfm-markdown
          v-if="isMarkdown"
          :markdown="item.content"
          class="gl-m-0 gl-flex-1 gl-py-2 gl-pr-7 gl-wrap-anywhere"
          data-testid="log-entry-markdown"
        />
        <div v-else class="gl-m-0 gl-flex-1 gl-py-2" data-testid="log-entry-plain-text">
          {{ item.content }}
        </div>
        <code v-if="filePath" class="gl-break-all" data-testid="log-entry-file-path">
          {{ filePath }}
        </code>
      </div>
      <gl-button
        v-if="toolInfo"
        :icon="collapseIcon"
        size="small"
        category="tertiary"
        :aria-label="s__('DuoAgentPlatform|Show tool details')"
        data-testid="log-entry-collapse-button"
        @click="visible = !visible"
      />
    </div>
    <gl-collapse v-if="toolInfo" :visible="visible" data-testid="log-entry-collapse">
      <message-tool-kv-section class="gl-mt-4" title="Request" :value="toolInfo.args" />
    </gl-collapse>
  </div>
</template>
