<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';

export default {
  name: 'VulnerabilitiesPopover',
  components: {
    UserCalloutDismisser,
    GlIcon,
    GlPopover,
  },
};
</script>

<template>
  <user-callout-dismisser ref="calloutDismisser" feature-name="focused_vulnerability_reporting">
    <template #default="{ dismiss, shouldShowCallout }">
      <div>
        <gl-icon id="vulnerabilities-info" name="information-o" class="gl-ml-2" variant="info" />
        <gl-popover
          :show="shouldShowCallout"
          :title="s__('Dependencies|Focused vulnerability reporting')"
          placement="bottom"
          boundary="viewport"
          target="vulnerabilities-info"
          show-close-button
          data-testid="vulnerability-info-popover"
          @close-button-clicked="dismiss"
        >
          <p class="gl-mb-0">
            {{
              s__(
                'Dependencies|The dependency list excludes vulnerabilities that are no longer detected in the project. Removing these vulnerabilities gives you a more accurate risk assessment of each component.',
              )
            }}
          </p>
        </gl-popover>
      </div>
    </template>
  </user-callout-dismisser>
</template>
