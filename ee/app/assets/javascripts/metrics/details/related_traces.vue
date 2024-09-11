<script>
import { GlLink, GlIcon, GlSprintf } from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime_utility';
import { SHORT_DATE_TIME_FORMAT } from '~/observability/constants';
import { viewTracesUrlWithMetric } from './utils';

export default {
  components: {
    GlLink,
    GlIcon,
    GlSprintf,
  },
  props: {
    dataPoints: {
      type: Array,
      required: true,
    },
    tracingIndexUrl: {
      type: String,
      required: true,
    },
  },
  computed: {
    itemsWithTracingUrl() {
      return this.dataPoints.map((dataPoint) => ({
        ...dataPoint,
        url: this.getTracesUrl(dataPoint),
      }));
    },
    timeUtcString() {
      const { timestamp } = this.dataPoints[0] || {};

      return timestamp ? formatDate(timestamp, SHORT_DATE_TIME_FORMAT) : null;
    },
    hasTraces() {
      return this.dataPoints.some(({ traceIds }) => traceIds.length > 0);
    },
    showWidget() {
      return this.dataPoints.length > 0;
    },
  },
  methods: {
    getTracesUrl(dataPoint) {
      if (dataPoint.traceIds.length < 1) return null;

      return viewTracesUrlWithMetric(this.tracingIndexUrl, dataPoint);
    },
  },
};
</script>

<template>
  <section v-if="showWidget">
    <h5>
      <gl-sprintf :message="s__('ObservabilityMetrics|Related traces at %{time}')">
        <template #time>{{ timeUtcString }}</template>
      </gl-sprintf>
    </h5>

    <ul v-if="hasTraces" class="gl-m-0 gl-list-none gl-p-0" data-testid="traces-list">
      <li
        v-for="item in itemsWithTracingUrl"
        :key="item.seriesName"
        class="gl-flex gl-items-center gl-gap-3"
      >
        <gl-icon name="status_created" :size="16" :style="{ color: item.color }" />
        <span>
          {{ item.seriesName }}
          <gl-sprintf :message="s__('ObservabilityMetrics|(Value: %{value})')">
            <template #value>{{ item.value }}</template>
          </gl-sprintf>
        </span>
        <gl-link v-if="item.url" :href="item.url">{{
          s__('ObservabilityMetrics|View traces')
        }}</gl-link>
        <span v-else class="gl-text-secondary">{{
          s__('ObservabilityMetrics|No related traces')
        }}</span>
      </li>
    </ul>

    <p v-else class="gl-text-gray-500">
      {{
        s__(
          'ObservabilityMetrics|No related traces for the selected time. Select another data point and try again.',
        )
      }}
    </p>
  </section>
</template>
