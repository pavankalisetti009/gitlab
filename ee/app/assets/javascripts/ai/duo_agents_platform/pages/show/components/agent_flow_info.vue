<script>
import { GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { s__, __ } from '~/locale';

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
          key: __('Type'),
          value: this.agentFlowDefinition,
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
};
</script>
<template>
  <div>
    <ul>
      <li v-for="entry in payload" :key="entry.key" class="gl-mb-4 gl-flex gl-list-none">
        <strong class="gl-pr-3">{{ entry.key }}:</strong>
        <template v-if="isLoading"><gl-skeleton-loader :lines="1" /></template>
        <template v-else>
          <gl-link v-if="entry.link" :href="entry.link">{{ entry.value }}</gl-link>
          <span v-else>{{ entry.value }}</span>
        </template>
      </li>
    </ul>
  </div>
</template>
