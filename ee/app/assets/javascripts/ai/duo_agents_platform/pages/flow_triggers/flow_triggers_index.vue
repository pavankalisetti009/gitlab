<script>
import { s__ } from '~/locale';

export default {
  name: 'FlowTriggersIndex',
  i18n: {
    title: s__('DuoAgentsPlatform|Flow triggers'),
    description: s__('DuoAgentsPlatform|Manage automated AI workflows within your project.'),
  },
};
</script>
<template>
  <div>
    <h1>{{ $options.i18n.title }}</h1>
    <p>{{ $options.i18n.description }}</p>
  </div>
</template>
