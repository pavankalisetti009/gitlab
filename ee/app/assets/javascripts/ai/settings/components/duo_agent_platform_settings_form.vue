<script>
import { GlCollapse, GlFormGroup, GlFormCheckbox } from '@gitlab/ui';

export default {
  name: 'DuoAgentPlatformSettingsForm',
  components: {
    GlCollapse,
    GlFormGroup,
    GlFormCheckbox,
  },
  inject: ['showDuoAgentPlatformEnablementSetting'],
  props: {
    enabled: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['selected'],
  methods: {
    onDuoAgentPlatformEnabledChanged(value) {
      this.$emit('selected', value);
    },
  },
};
</script>
<template>
  <div class="gl-my-4">
    <gl-form-group
      v-if="showDuoAgentPlatformEnablementSetting"
      :label="s__('AiPowered|GitLab Duo Agent Platform')"
    >
      <gl-form-checkbox :checked="enabled" @input="onDuoAgentPlatformEnabledChanged">
        {{ s__('AiPowered|Turn on GitLab Duo Chat (Agentic), agents, and flows') }}
      </gl-form-checkbox>
    </gl-form-group>
    <gl-collapse :visible="enabled">
      <slot></slot>
    </gl-collapse>
  </div>
</template>
