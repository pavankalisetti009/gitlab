<script>
import { GlButton } from '@gitlab/ui';
import { FLOW_TRIGGERS_NEW_ROUTE } from '../../../../router/constants';

export default {
  name: 'FlowTriggersCta',
  components: {
    GlButton,
  },
  newPage: FLOW_TRIGGERS_NEW_ROUTE,
};
</script>

<template>
  <gl-button variant="confirm" :to="{ name: $options.newPage }">
    {{ s__('DuoAgentsPlatform|New trigger') }}
  </gl-button>
</template>
