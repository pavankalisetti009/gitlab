<script>
import { s__, sprintf } from '~/locale';
import { convertTypeEnumToName } from '~/work_items/utils';
import { NAME_TO_TEXT_MAP } from '~/work_items/constants';
import ChangeLifecycleStepper from './change_lifecycle_stepper.vue';
import SelectLifecycle from './select_lifecycle.vue';

export default {
  name: 'ChangeLifecycle',
  components: {
    ChangeLifecycleStepper,
    SelectLifecycle,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  steps: [
    {
      label: s__('WorkItem|Select lifecycle'),
      description: s__('WorkItem|Lifecycle selection'),
    },
    {
      label: s__('WorkItem|Update work items'),
      description: s__('WorkItem|Update work items'),
    },
  ],
  computed: {
    selectedWorkItemType() {
      return convertTypeEnumToName(this.$route.params.workItemType.toUpperCase());
    },
    title() {
      return sprintf(s__('WorkItem|Change lifecycle: %{workItemType}'), {
        workItemType: NAME_TO_TEXT_MAP[this.selectedWorkItemType],
      });
    },
  },
};
</script>

<template>
  <div>
    <h1 class="gl-mb-6 gl-text-size-h-display">{{ title }}</h1>
    <change-lifecycle-stepper
      :steps="$options.steps"
      :allow-skip="false"
      :show-finish-button="false"
      @validate-step="() => {}"
      @finish="() => {}"
      @cancel="() => {}"
    >
      <template #step-0>
        <select-lifecycle :work-item-type="selectedWorkItemType" :full-path="fullPath" />
      </template>
      <template #step-1>
        {{ __('Step 2') }}
      </template>
    </change-lifecycle-stepper>
  </div>
</template>
