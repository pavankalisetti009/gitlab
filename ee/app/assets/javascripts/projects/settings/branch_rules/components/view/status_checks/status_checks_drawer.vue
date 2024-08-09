<script>
import { GlDrawer } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import StatusChecksForm from './status_checks_form.vue';

export default {
  DRAWER_Z_INDEX,
  name: 'StatusChecksDrawer',
  i18n: {
    addStatusCheck: s__('BranchRules|Add status check'),
  },
  components: {
    GlDrawer,
    StatusChecksForm,
  },
  props: {
    isOpen: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    statusChecks: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
  },
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    :open="isOpen"
    @close="$emit('close')"
  >
    <template #title>
      <h2 class="gl-mt-0 gl-text-size-h2">{{ $options.i18n.addStatusCheck }}</h2>
    </template>

    <template #default>
      <status-checks-form
        :status-checks="statusChecks"
        :is-loading="isLoading"
        data-testid="status-checks-form"
        @saveChanges="$emit('saveChanges')"
        @close="$emit('close')"
      />
    </template>
  </gl-drawer>
</template>
