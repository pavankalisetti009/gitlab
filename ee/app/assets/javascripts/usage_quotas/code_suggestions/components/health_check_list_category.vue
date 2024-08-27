<script>
import HealthCheckListProbe from './health_check_list_probe.vue';

export default {
  name: 'HealthCheckListCategory',
  components: {
    HealthCheckListProbe,
  },
  props: {
    category: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <article>
    <header class="gl-mb-2 gl-font-bold gl-text-gray-700">
      {{ category.title }}
    </header>
    <p class="gl-mb-0 gl-text-gray-700">
      {{ category.description }}
    </p>

    <health-check-list-probe
      v-for="(probe, index) in category.probes"
      :key="index"
      :probe="probe"
    />
  </article>
</template>
