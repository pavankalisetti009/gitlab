<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'AvailabilityPopover',
  components: {
    GlIcon,
    GlPopover,
  },
  AGENT_CONFIG_NOTE_POPOVER_CONTENT: s__(
    "Workspaces|In order to make an agent available/blocked, workspaces must be enabled in the agent's configuration.",
  ),
  BLOCKING_AGENT_POPOVER_CONTENT: s__(
    "Workspaces|Blocking an agent doesn't delete it. Agents can only be deleted in the project where they were created. In addition, existing workspaces using a blocked agent will continue to run.",
  ),
};
</script>
<template>
  <div>
    <gl-icon id="question-icon" name="question-o" />
    <gl-popover target="question-icon">
      <p>{{ $options.AGENT_CONFIG_NOTE_POPOVER_CONTENT }}</p>
      <p>{{ $options.BLOCKING_AGENT_POPOVER_CONTENT }}</p>
    </gl-popover>
  </div>
</template>
