<script>
import { s__ } from '~/locale';

export default {
  name: 'FlowTriggersShow',
  i18n: {
    title: s__('DuoAgentsPlatform|Flow trigger details'),
    description: s__('DuoAgentsPlatform|View and manage this flow trigger.'),
  },
};
</script>

<template>
  <div>
    <h1>{{ $options.i18n.title }}</h1>
    <p>{{ $options.i18n.description }}</p>
  </div>
</template>
