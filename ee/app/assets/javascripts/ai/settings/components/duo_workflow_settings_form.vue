<script>
import { GlFormCheckbox, GlFormGroup, GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { PROTECTION_LEVEL_OPTIONS } from '../constants';

const PROTECTION_LEVEL_VALUES = PROTECTION_LEVEL_OPTIONS.map((option) => option.value);

export default {
  name: 'DuoWorkflowSettingsForm',
  components: {
    GlFormCheckbox,
    GlFormGroup,
    GlFormRadio,
    GlFormRadioGroup,
  },
  props: {
    isMcpEnabled: {
      type: Boolean,
      required: true,
    },
    showMcp: {
      type: Boolean,
      required: true,
    },
    promptInjectionProtectionLevel: {
      type: String,
      required: true,
      validator: (value) => PROTECTION_LEVEL_VALUES.includes(value),
    },
    showProtection: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      selectedProtectionLevel: this.promptInjectionProtectionLevel,
    };
  },
  watch: {
    promptInjectionProtectionLevel(newValue) {
      this.selectedProtectionLevel = newValue;
    },
  },
  methods: {
    checkboxChanged(value) {
      this.$emit('mcp-change', value);
    },
    onProtectionLevelChange(value) {
      this.$emit('protection-level-change', value);
    },
  },
  protectionLevelOptions: PROTECTION_LEVEL_OPTIONS,
};
</script>
<template>
  <div class="gl-flex gl-flex-col gl-gap-4">
    <div v-if="showMcp">
      <h5>{{ s__('DuoWorkflowSettings|External MCP tools') }}</h5>

      <gl-form-checkbox
        :checked="isMcpEnabled"
        data-testid="enable-duo-workflow-mcp-enabled-checkbox"
        name="namespace[ai_settings_attributes][duo_workflow_mcp_enabled]"
        @change="checkboxChanged"
      >
        <span id="enable-duo-workflow-mcp-enabled-checkbox-label">{{
          s__('DuoWorkflowSettings|Allow external MCP tools')
        }}</span>
        <template #help>
          {{ s__('DuoWorkflowSettings|Allow the IDE to access external MCP tools.') }}
        </template>
      </gl-form-checkbox>
    </div>

    <div v-if="showProtection">
      <gl-form-group
        :label="s__('DuoWorkflowSettings|Prompt injection protection')"
        :label-description="
          s__(
            'DuoWorkflowSettings|Control how GitLab Duo handles potential prompt injection attempts.',
          )
        "
      >
        <gl-form-radio-group
          v-model="selectedProtectionLevel"
          name="namespace[ai_settings_attributes][prompt_injection_protection_level]"
          data-testid="prompt-injection-protection-level-radio-group"
          @change="onProtectionLevelChange"
        >
          <gl-form-radio
            v-for="option in $options.protectionLevelOptions"
            :key="option.value"
            :value="option.value"
            :data-testid="`prompt-injection-protection-${option.value}-radio`"
          >
            <div>
              {{ option.text }}
              <p class="gl-mb-0 gl-text-subtle">{{ option.description }}</p>
            </div>
          </gl-form-radio>
        </gl-form-radio-group>
      </gl-form-group>
    </div>
  </div>
</template>
