<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'AvailabilityPopover',
  components: {
    GlIcon,
    GlPopover,
  },
  POPOVER_TEXT: s__(
    "Workspaces|Blocking an agent doesn't delete it. Agents can only be deleted in the project where they were created. In addition, existing workspaces using a blocked agent will continue to run.",
  ),
};
</script>
<template>
  <div>
    <gl-icon id="question-icon" name="question-o" />
    <gl-popover target="question-icon">
      {{ $options.POPOVER_TEXT }}
    </gl-popover>
  </div>
</template>
