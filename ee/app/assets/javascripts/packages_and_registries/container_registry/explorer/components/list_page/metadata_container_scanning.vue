<script>
import { GlSkeletonLoader, GlIcon, GlPopover, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { fetchPolicies } from '~/lib/graphql';
import getProjectContainerScanning from '../../graphql/queries/get_project_container_scanning.query.graphql';

export default {
  components: {
    GlIcon,
    GlSkeletonLoader,
    GlPopover,
    GlLink,
  },
  inject: ['config'],
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    containerScanningData: {
      query: getProjectContainerScanning,
      variables() {
        return {
          fullPath: this.config.projectPath,
          securityConfigurationPath: this.config.securityConfigurationPath,
        };
      },
      // We need this for handling loading state when using frontend cache
      // See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/106004#note_1217325202 for details
      fetchPolicy: fetchPolicies.CACHE_ONLY,
      notifyOnNetworkStatusChange: true,
      update(data) {
        return data.project.containerScanningForRegistry ?? { isEnabled: false, isVisible: false };
      },
    },
  },
  computed: {
    isMetaVisible() {
      return this.containerScanningData?.isVisible;
    },
    metaText() {
      return this.containerScanningData?.isEnabled
        ? s__('ContainerRegistry|Container Scanning for Registry: On')
        : s__('ContainerRegistry|Container Scanning for Registry: Off');
    },
  },
};
</script>

<template>
  <div class="gl-inline-flex gl-items-center">
    <gl-skeleton-loader v-if="$apollo.queries.containerScanningData.loading" :lines="1" />
    <template v-if="isMetaVisible">
      <div id="popover-target" data-testid="container-scanning-metadata">
        <gl-icon name="shield" class="gl-mr-3 gl-min-w-5 gl-text-gray-500" /><span
          class="gl-inline-flex gl-font-bold"
          >{{ metaText }}</span
        >
      </div>
      <gl-popover
        data-testid="container-scanning-metadata-popover"
        target="popover-target"
        triggers="hover focus click"
        placement="bottom"
      >
        {{
          s__(
            'ContainerRegistry|Continuous container scanning runs in the registry when any image or database is updated.',
          )
        }}
        <br />
        <br />
        <gl-link :href="config.containerScanningForRegistryDocsPath" class="gl-font-bold">
          {{ __('What is continuous container scanning?') }}
        </gl-link>
      </gl-popover>
    </template>
  </div>
</template>
