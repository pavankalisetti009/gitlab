<script>
import { s__ } from '~/locale';

export default {
  name: 'ScheduleForm',
  i18n: {
    message: s__('SecurityOrchestration|Schedules'),
  },
};
</script>

<template>
  <div>
    {{ $options.i18n.message }}
  </div>
</template>
