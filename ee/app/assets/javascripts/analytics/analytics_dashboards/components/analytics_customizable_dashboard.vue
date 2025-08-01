<script>
import { GlExperimentBadge } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import GridstackWrapper from '~/vue_shared/components/customizable_dashboard/gridstack_wrapper.vue';

export default {
  name: 'AnalyticsCustomizableDashboard',
  components: {
    GlExperimentBadge,
    GridstackWrapper,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    dashboard: {
      type: Object,
      required: true,
      default: () => {},
    },
  },
  computed: {
    showFilters() {
      return this.$scopedSlots.filters;
    },
    showDashboardDescription() {
      return Boolean(this.dashboard.description);
    },
    statusBadgeType() {
      return this.dashboard?.status || null;
    },
    dashboardDescription() {
      return this.dashboard.description;
    },
  },
  mounted() {
    const wrappers = document.querySelectorAll('.container-fluid.container-limited');

    wrappers.forEach((el) => {
      el.classList.add('not-container-limited');
      el.classList.remove('container-limited');
    });
  },
  beforeDestroy() {
    const wrappers = document.querySelectorAll('.container-fluid.not-container-limited');

    wrappers.forEach((el) => {
      el.classList.add('container-limited');
      el.classList.remove('not-container-limited');
    });
  },
};
</script>

<template>
  <div>
    <section class="gl-my-4 gl-flex gl-items-center">
      <div class="gl-flex gl-w-full gl-flex-col">
        <div class="gl-flex gl-items-center">
          <h2 data-testid="dashboard-title" class="gl-my-0">{{ dashboard.title }}</h2>
          <gl-experiment-badge v-if="statusBadgeType" class="gl-ml-3" :type="statusBadgeType" />
        </div>
        <div
          v-if="showDashboardDescription"
          class="gl-mt-3 gl-flex"
          data-testid="dashboard-description"
        >
          <p class="gl-mb-0">
            {{ dashboardDescription }}
            <slot name="after-description"></slot>
          </p>
        </div>
      </div>
    </section>
    <div class="-gl-mx-3">
      <div class="gl-flex">
        <div class="gl-flex gl-grow gl-flex-col">
          <section
            v-if="showFilters"
            data-testid="dashboard-filters"
            class="gl-flex gl-flex-row gl-flex-wrap gl-gap-5 gl-px-3 gl-pb-3 gl-pt-4"
          >
            <slot name="filters"></slot>
          </section>

          <slot name="alert"></slot>
          <gridstack-wrapper :value="dashboard">
            <template #panel="{ panel }">
              <slot name="panel" v-bind="{ panel }"></slot>
            </template>
          </gridstack-wrapper>
        </div>
      </div>
    </div>
  </div>
</template>
