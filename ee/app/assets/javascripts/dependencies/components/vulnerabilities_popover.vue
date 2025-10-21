<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import { __, s__ } from '~/locale';

export default {
  name: 'VulnerabilitiesPopover',
  components: {
    UserCalloutDismisser,
    GlIcon,
    GlPopover,
  },
  props: {},
  data() {
    return {
      showPopover: false,
    };
  },
  mounted() {
    setTimeout(() => {
      this.showPopover = true;
    }, 1000);
  },
};
</script>

<template>
  <user-callout-dismisser
    v-if="showPopover"
    ref="calloutDismisser"
    feature-name="focused_vulnerability_reporting"
  >
    <template #default="{ dismiss, shouldShowCallout }">
      <div>
        <gl-icon id="vulnerabilities-info" name="information-o" class="gl-ml-2" variant="info" />
        <gl-popover
          placement="bottom"
          boundary="viewport"
          target="vulnerabilities-info"
          data-testid="vulnerability-info-popover"
          show-close-button
          :show="shouldShowCallout"
          :title="s__('Dependencies|Focused vulnerability reporting')"
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
