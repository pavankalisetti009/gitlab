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
          triggers="manual"
          show-close-button
          data-testid="vulnerability-info-popover"
          @close-button-clicked="dismiss"
        >
          <p class="gl-mb-0">
            {{
              s__(
                'Dependencies|The dependency list shows only active, currently detected issues. Vulnerabilities that are no longer detected are filtered out.',
              )
            }}
          </p>
        </gl-popover>
      </div>
    </template>
  </user-callout-dismisser>
</template>
