<script>
import { GlDrawer, GlSprintf } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import ScanResultDetailsDrawer from 'ee/security_orchestration/components/policy_drawer/scan_result/details_drawer.vue';
import InfoRow from 'ee/security_orchestration/components/policy_drawer/info_row.vue';

export default {
  components: {
    GlDrawer,
    GlSprintf,
    InfoRow,
    ScanResultDetailsDrawer,
  },
  props: {
    open: {
      type: Boolean,
      required: true,
    },
    policy: {
      type: Object,
      required: false,
      default: null,
    },
    comparisonPipelines: {
      type: Object,
      required: false,
      default: null,
    },
    targetBranch: {
      type: String,
      required: true,
    },
    sourceBranch: {
      type: String,
      required: true,
    },
  },
  computed: {
    getDrawerHeaderHeight() {
      if (!this.open) return '0';
      return getContentWrapperHeight();
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    :open="open"
    @close="$emit('close')"
  >
    <template #title>
      <h4 class="gl-my-0">{{ __('Security policy') }}</h4>
    </template>
    <div v-if="policy">
      <h5 class="h4 gl-mb-0 gl-mt-0">{{ policy.name }}</h5>
      <scan-result-details-drawer :policy="policy" :show-policy-scope="false" :show-status="false">
        <template v-if="comparisonPipelines" #additional-details>
          <info-row :label="__('Comparison pipelines')">
            <ul class="gl-pl-6">
              <li class="gl-mb-2">
                <gl-sprintf :message="__('Target branch (%{branch})')">
                  <template #branch>
                    <code>{{ targetBranch }}</code>
                  </template>
                </gl-sprintf>
              </li>
              <li>
                <gl-sprintf :message="__('Source branch (%{branch})')">
                  <template #branch>
                    <code>{{ sourceBranch }}</code>
                  </template>
                </gl-sprintf>
              </li>
            </ul>
          </info-row>
        </template>
      </scan-result-details-drawer>
    </div>
  </gl-drawer>
</template>
