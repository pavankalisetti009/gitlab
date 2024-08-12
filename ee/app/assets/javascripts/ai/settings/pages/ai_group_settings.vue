<script>
import AiCommonSettings from '../components/ai_common_settings.vue';

export default {
  name: 'AiGroupSettings',
  components: {
    AiCommonSettings,
  },
  duoAvailability: '',
  duoFeaturesEnabledLocked: false,
};
</script>
<template>
  <ai-common-settings
    :duo-availability="$options.duoAvailability"
    :duo-features-enabled-locked="$options.duoFeaturesEnabledLocked"
  />
</template>
