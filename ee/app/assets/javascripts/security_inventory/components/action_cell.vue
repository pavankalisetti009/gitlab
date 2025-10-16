<script>
import { GlDisclosureDropdown } from '@gitlab/ui';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { isSubGroup } from '../utils';
import {
  PROJECT_SECURITY_CONFIGURATION_PATH,
  PROJECT_VULNERABILITY_REPORT_PATH,
  GROUP_VULNERABILITY_REPORT_PATH,
} from '../constants';

export default {
  components: {
    GlDisclosureDropdown,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  methods: {
    vulnerabilityReportPath(item) {
      if (!item?.webUrl) return '#';

      return isSubGroup(item)
        ? `${item.webUrl}${GROUP_VULNERABILITY_REPORT_PATH}`
        : `${item.webUrl}${PROJECT_VULNERABILITY_REPORT_PATH}`;
    },
    toolCoveragePath(item) {
      return item?.webUrl ? `${item.webUrl}${PROJECT_SECURITY_CONFIGURATION_PATH}` : '#';
    },
    getActionItems(item) {
      const hasWebUrl = Boolean(item?.webUrl);
      const isGroup = isSubGroup(item);

      const items = [
        {
          text: isGroup
            ? s__('SecurityInventory|View subgroup')
            : s__('SecurityInventory|View project'),
          href: hasWebUrl ? item.webUrl : '#',
        },
        {
          text: s__('SecurityInventory|View vulnerability report'),
          href: this.vulnerabilityReportPath(item),
        },
      ];

      if (!isGroup) {
        items.push({
          text: s__('SecurityInventory|Manage tool coverage'),
          href: this.toolCoveragePath(item),
        });
        if (this.glFeatures.securityContextLabels) {
          items.push({
            text: s__('SecurityInventory|Edit security attributes'),
            action: () => this.$emit('openAttributesDrawer', item),
          });
        }
      }

      return items;
    },
  },
};
</script>
<template>
  <gl-disclosure-dropdown
    category="tertiary"
    variant="default"
    size="small"
    icon="ellipsis_v"
    no-caret
    :items="getActionItems(item)"
  />
</template>
