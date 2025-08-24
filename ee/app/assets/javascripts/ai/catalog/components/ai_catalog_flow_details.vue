<script>
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

export default {
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    steps() {
      return (
        this.item.latestVersion?.steps?.nodes?.map(({ agent }) => ({
          agent: { name: agent.name, id: getIdFromGraphQLId(agent.id) },
        })) || []
      );
    },
  },
};
</script>

<template>
  <div>
    <dt>{{ s__('AICatalog|Steps') }}</dt>
    <dd v-for="(step, index) in steps" :key="index">{{ step.agent.name }} ({{ step.agent.id }})</dd>
  </div>
</template>
