<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isSubGroup } from '../utils';
import { PROJECT_SECURITY_CONFIGURATION_PATH } from '../constants';

export default {
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    projectConfigurationTooltipTitle: s__('SecurityInventory|Manage security configuration'),
  },
  methods: {
    isSubGroup,
    projectSecurityConfigurationPath(item) {
      return item?.webUrl ? `${item.webUrl}${PROJECT_SECURITY_CONFIGURATION_PATH}` : '#';
    },
  },
};
</script>

<template>
  <gl-button
    v-if="!isSubGroup(item)"
    v-gl-tooltip.hover.left
    :href="projectSecurityConfigurationPath(item)"
    class="gl-ml-3"
    :aria-label="$options.i18n.projectConfigurationTooltipTitle"
    :title="$options.i18n.projectConfigurationTooltipTitle"
    icon="settings"
  />
</template>
