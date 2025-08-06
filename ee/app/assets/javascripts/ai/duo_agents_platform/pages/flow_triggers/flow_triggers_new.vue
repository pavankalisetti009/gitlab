<script>
import { s__ } from '~/locale';

export default {
  name: 'FlowTriggersNew',
  i18n: {
    title: s__('DuoAgentsPlatform|New flow trigger'),
    description: s__('DuoAgentsPlatform|Create a new automated AI workflow trigger.'),
  },
};
</script>

<template>
  <div>
    <h1>{{ $options.i18n.title }}</h1>
    <p>{{ $options.i18n.description }}</p>
  </div>
</template>
