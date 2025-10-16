<script>
import { GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';
import { joinPaths } from '~/lib/utils/url_utility';

const AGENT_SESSIONS_PATH = '/-/automate/agent-sessions';

export default {
  components: {
    GlLink,
    GlSkeletonLoader,
  },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    status: {
      required: true,
      type: String,
    },
    agentFlowDefinition: {
      required: true,
      type: String,
    },
    executorUrl: {
      required: false,
      type: String,
      default: '',
    },
    createdAt: {
      type: String,
      required: false,
      default: '',
    },
    updatedAt: {
      type: String,
      required: false,
      default: '',
    },
    project: {
      type: Object,
      required: true,
    },
  },
  computed: {
    executorId() {
      const id = this.executorUrl.split('/').pop();
      if (!id || Number.isNaN(Number(id))) {
        return null;
      }
      return id;
    },
    projectAgentSessionsUrl() {
      const sessionId = this.$route.params.id;
      const projectUrl = this.project?.webUrl;

      return sessionId && projectUrl
        ? joinPaths(projectUrl, `${AGENT_SESSIONS_PATH}/${sessionId}`)
        : '';
    },
    payload() {
      return [
        {
          key: __('Status'),
          value: this.status,
        },
        {
          key: __('Project'),
          value: this.project?.name,
          link: this.project?.webUrl,
        },
        {
          key: __('Group'),
          value: this.project?.namespace?.name,
          link: this.project?.namespace?.webUrl,
        },
        {
          key: __('Started'),
          value: this.formatTimestamp(this.createdAt),
        },
        {
          key: __('Last updated'),
          value: this.formatTimestamp(this.updatedAt),
        },
        {
          key: 'Type',
          value: s__('DuoAgentPlatform|Flow'),
        },
        {
          key: s__('AI|Flow'),
          value: this.agentFlowDefinition,
        },
        {
          key: s__('DuoAgentPlatform|Session ID'),
          value: this.$route.params.id,
          link: this.projectAgentSessionsUrl,
        },
        {
          key: s__('DuoAgentPlatform|Executor ID'),
          value: this.executorId,
          link: this.executorUrl,
        },
      ].map((entry) => {
        return { ...entry, value: entry.value ? entry.value : __('N/A') };
      });
    },
  },
  methods: {
    formatTimestamp(isoString) {
      if (!isoString) {
        return __('N/A');
      }

      try {
        const date = new Date(isoString);
        if (Number.isNaN(date.getTime())) {
          return __('N/A');
        }
        return localeDateFormat.asDateTime.format(date);
      } catch (error) {
        return __('N/A');
      }
    },
  },
};
</script>
<template>
  <div>
    <dl class="gl-pl-4">
      <div v-for="entry in payload" :key="entry.key" class="gl-mb-6">
        <dt class="gl-mb-2">{{ entry.key }}</dt>
        <template v-if="isLoading">
          <dd>
            <gl-skeleton-loader :lines="1" />
          </dd>
        </template>
        <template v-else>
          <dd>
            <gl-link v-if="entry.link" :href="entry.link">{{ entry.value }}</gl-link>
            <template v-else>{{ entry.value }}</template>
          </dd>
        </template>
      </div>
    </dl>
  </div>
</template>
