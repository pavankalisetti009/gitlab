<script>
import { GlBadge, GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';
import { joinPaths } from '~/lib/utils/url_utility';
import { getAgentStatusBadge } from '../../../utils';

const AGENT_SESSIONS_PATH = '/-/automate/agent-sessions';

export default {
  components: {
    GlBadge,
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
    humanStatus: {
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
    itemStatus() {
      return getAgentStatusBadge(this.status);
    },
    jobId() {
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
          key: s__('DuoAgentPlatform|Session ID'),
          value: this.$route.params.id,
          link: this.projectAgentSessionsUrl,
        },
        {
          key: __('Status'),
          value: this.humanStatus,
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
          key: 'Type',
          value: s__('DuoAgentPlatform|Flow'),
        },
        {
          key: s__('AI|Flow'),
          value: this.agentFlowDefinition,
        },
        {
          key: s__('DuoAgentPlatform|Job ID'),
          value: this.jobId,
          link: this.executorUrl,
        },
        {
          key: __('Started'),
          value: this.formatTimestamp(this.createdAt),
        },
        {
          key: __('Last updated'),
          value: this.formatTimestamp(this.updatedAt),
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
    <div class="gl-pl-4">
      <h5 data-testid="session-info-heading">{{ s__('DuoAgentPlatform|Session information') }}</h5>
      <ul class="gl-list-none gl-p-0">
        <li v-for="entry in payload" :key="entry.key" class="gl-mb-4">
          <span class="gl-mb-2 gl-text-subtle" data-testid="info-title">
            {{ sprintf(__('%{label}:'), { label: entry.key }) }}
          </span>
          <template v-if="isLoading">
            <gl-skeleton-loader :lines="1" />
          </template>
          <template v-else>
            <span data-testid="info-value">
              <gl-link v-if="entry.link" :href="entry.link">{{ entry.value }}</gl-link>
              <gl-badge
                v-else-if="entry.key === 'Status'"
                class="gl-mr-3"
                :variant="itemStatus.variant"
              >
                {{ entry.value }}
              </gl-badge>
              <template v-else>{{ entry.value }}</template>
            </span>
          </template>
        </li>
      </ul>
    </div>
  </div>
</template>
