<script>
import { s__ } from '~/locale';

export default {
  name: 'CodeFlowFileViewer',
  i18n: {
    tempText: s__('Vulnerability|code area'),
  },
};
</script>

<template>
  <div class="file-holder">{{ $options.i18n.tempText }}</div>
</template>
