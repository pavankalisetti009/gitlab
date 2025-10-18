<script>
import { GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getTimeago } from '~/lib/utils/datetime_utility';
import NonGfmMarkdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';

import { getMessageData } from '../../utils';
import ActivityConnectorSvg from './activity_connector_svg.vue';

export default {
  components: {
    ActivityConnectorSvg,
    GlIcon,
    NonGfmMarkdown,
  },
  props: {
    items: {
      type: Array,
      required: true,
      validator(items) {
        return items.every(
          (item) =>
            typeof item === 'object' &&
            item.content &&
            item.message_type &&
            item.status &&
            item.timestamp,
        );
      },
    },
  },
  data() {
    return {
      iconRefs: [],
    };
  },
  watch: {
    items: {
      handler: 'getTargets',
      immediate: true,
    },
  },
  mounted() {
    window.addEventListener('resize', this.getTargets);
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.getTargets);
  },
  methods: {
    assignIcon(message, index) {
      // TODO: The starting message might warrant its own type
      // https://gitlab.com/gitlab-org/gitlab/-/issues/562418
      if (index === 0) {
        return this.$options.startMessage.icon;
      }

      return getMessageData(message)?.icon;
    },
    filePath(item) {
      return item.tool_info?.args?.file_path;
    },
    isMarkdown(item, index) {
      return item.message_type !== 'user' && index > 0;
    },
    title(message, index) {
      if (index === 0) {
        return this.$options.startMessage.title;
      }

      return getMessageData(message)?.title;
    },
    timeAgo(message) {
      return getTimeago().format(message.timestamp);
    },
    getTargets() {
      if (this.items.length === 0) return;

      setTimeout(() => {
        this.iconRefs = [this.$refs[`icon-0`][0], this.$refs[`icon-${this.items.length - 1}`][0]];
        // Whenever we call getTarget, let's force a re-render even if the array reference is the same, other
        // factors may also have changed
        this.$forceUpdate();
      }, 1);
    },
  },
  startMessage: { icon: 'play', title: s__('DuoAgentPlatform|Session triggered'), level: 1 },
};
</script>
<template>
  <ul id="activity-list" class="gl-relative gl-flex gl-flex-col gl-pl-0">
    <activity-connector-svg :targets="iconRefs" />

    <li v-for="(item, index) in items" :key="item.id" class="gl-relative gl-mb-5 gl-flex gl-w-full">
      <div :ref="`icon-${index}`" class="gl-relative gl-mr-4 gl-flex gl-flex-col gl-items-center">
        <div class="gl-border gl-rounded-full gl-bg-strong gl-p-2">
          <gl-icon :name="assignIcon(item, index)" variant="subtle" />
        </div>
      </div>

      <div class="gl-w-full">
        <div class="gl-flex gl-justify-between">
          <strong class="gl-mb-1 gl-text-strong">{{ title(item, index) }}</strong>
          <span class="gl-text-subtle">{{ timeAgo(item) }}</span>
        </div>

        <non-gfm-markdown
          v-if="isMarkdown(item, index)"
          :markdown="item.content"
          class="gl-m-0 gl-flex-1 gl-py-2 gl-wrap-anywhere"
        />
        <div v-else class="gl-m-0 gl-flex-1 gl-py-2">
          {{ item.content }}
        </div>
        <code v-if="filePath(item)" class="gl-break-all">{{ filePath(item) }}</code>
      </div>
    </li>
  </ul>
</template>
