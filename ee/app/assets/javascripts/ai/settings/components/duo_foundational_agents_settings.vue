<script>
import { GlLink, GlSprintf, GlFormRadioGroup, GlFormRadio, GlFormGroup } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';

export default {
  name: 'FoundationalAgentsSettings',
  i18n: {
    sectionTitle: s__('FoundationalAgents|Foundational agents'),
    sectionDescription: s__(
      'FoundationalAgents|Control availability of %{linkStart}GitLab Duo Foundational agents%{linkEnd}',
    ),
    onByDefaultLabel: s__('FoundationalAgents|On by default'),
    onByDefaultHelpText: s__(
      'FoundationalAgents|New foundational agents are automatically enabled for projects in this group.',
    ),
    offByDefaultLabel: s__('FoundationalAgents|Off by default'),
    offByDefaultHelpText: s__('FoundationalAgents|Foundational agents are disabled by default.'),
  },
  components: {
    GlFormRadioGroup,
    GlFormRadio,
    GlFormGroup,
    GlLink,
    GlSprintf,
  },
  props: {
    enabled: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      enabledInput: this.enabled,
    };
  },
  methods: {
    radioChanged(value) {
      this.$emit('change', value);
    },
  },
  foundationalAgentsHelpPath: helpPagePath(
    'user/duo_agent_platform/agents/foundational_agents/_index.md',
  ),
};
</script>
<template>
  <div>
    <gl-form-group :label="$options.i18n.sectionTitle" class="gl-mt-4">
      <template #label-description>
        <gl-sprintf :message="$options.i18n.sectionDescription">
          <template #link="{ content }">
            <gl-link :href="$options.foundationalAgentsHelpPath" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </template>

      <gl-form-radio-group v-model="enabledInput">
        <gl-form-radio :value="true" @change="radioChanged">
          {{ $options.i18n.onByDefaultLabel }}

          <template #help>
            {{ $options.i18n.onByDefaultHelpText }}
          </template>
        </gl-form-radio>

        <gl-form-radio :value="false" @change="radioChanged">
          {{ $options.i18n.offByDefaultLabel }}

          <template #help>
            {{ $options.i18n.offByDefaultHelpText }}
          </template>
        </gl-form-radio>
      </gl-form-radio-group>
    </gl-form-group>
  </div>
</template>
