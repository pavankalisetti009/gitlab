<script>
import FeatureItem from './feature_item.vue';

export default {
  name: 'FeatureCard',
  components: { FeatureItem },
  props: {
    topHeader: {
      type: String,
      required: true,
    },
    bottomHeader: {
      type: String,
      required: true,
    },
    items: {
      type: Array,
      required: true,
    },
    openPopoverId: {
      type: String,
      required: false,
      default: null,
    },
    handlePopoverToggle: {
      type: Function,
      required: true,
    },
    testId: {
      type: String,
      required: false,
      default: null,
    },
  },
};
</script>

<template>
  <div
    class="gl-border gl-rounded-pill gl-border-purple-200 gl-bg-default gl-p-5 md:gl-p-7"
    :data-testid="testId"
  >
    <h4 class="gl-heading-4">
      {{ topHeader }}
    </h4>
    <p class="gl-mb-4 gl-text-secondary">
      {{ bottomHeader }}
    </p>
    <div class="gl-display-flex gl-flex-direction-column">
      <feature-item
        v-for="item in items"
        :id="item.id"
        :key="item.id"
        :text="item.text"
        :description="item.description"
        :link="item.link"
        :open-popover-id="openPopoverId"
        @popover-toggle="handlePopoverToggle"
      />
    </div>
  </div>
</template>
