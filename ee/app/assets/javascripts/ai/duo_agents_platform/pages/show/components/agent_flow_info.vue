<script>
import { GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';

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
      required: true,
    },
    updatedAt: {
      type: String,
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
    payload() {
      return [
        {
          key: __('Status'),
          value: this.status,
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
      return formatDate(isoString, 'mmm dd, yyyy - HH:MM:ss');
    },
  },
};
</script>
<template>
  <div>
    <ul class="gl-list-none gl-pl-4">
      <li v-for="entry in payload" :key="entry.key" class="gl-mb-6 gl-flex gl-flex-col">
        <strong class="gl-mb-2">{{ entry.key }}</strong>
        <template v-if="isLoading"><gl-skeleton-loader :lines="1" /></template>
        <template v-else>
          <gl-link v-if="entry.link" :href="entry.link">{{ entry.value }}</gl-link>
          <span v-else>{{ entry.value }}</span>
        </template>
      </li>
    </ul>
  </div>
</template>
