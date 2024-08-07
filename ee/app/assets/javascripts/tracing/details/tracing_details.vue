<script>
import { GlLoadingIcon, GlAlert, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { InternalEvents } from '~/tracking';
import { visitUrl, setUrlParams, getNormalizedURL } from '~/lib/utils/url_utility';
import { logsQueryFromAttributes } from 'ee/logs/list/filter_bar/filters';
import { TIME_RANGE_OPTIONS_VALUES } from '~/observability/constants';
import { validatedDateRangeQuery } from '~/observability/utils';
import { mapTraceToSpanTrees, SPANS_LIMIT } from '../trace_utils';
import { VIEW_TRACING_DETAILS_PAGE } from '../events';
import TracingChart from './tracing_chart.vue';
import TracingHeader from './tracing_header.vue';
import TracingDrawer from './tracing_drawer.vue';

export default {
  i18n: {
    error: s__('Tracing|Error: Failed to load trace details. Try reloading the page.'),
    prunedWarning: s__(
      'Tracing|This trace has %{totalSpans} spans. For performance reasons, we only show the first %{spansLimit} spans.',
    ),
  },
  components: {
    GlLoadingIcon,
    TracingChart,
    TracingHeader,
    TracingDrawer,
    GlAlert,
    GlSprintf,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    observabilityClient: {
      required: true,
      type: Object,
    },
    traceId: {
      required: true,
      type: String,
    },
    tracingIndexUrl: {
      required: true,
      type: String,
    },
    logsIndexUrl: {
      required: true,
      type: String,
    },
  },
  data() {
    return {
      trace: null,
      spanTrees: null,
      loading: false,
      isDrawerOpen: false,
      selectedSpan: null,
      isTracePruned: false,
    };
  },
  computed: {
    logsLink() {
      return setUrlParams(
        logsQueryFromAttributes({
          traceId: this.traceId,
          dateRange: validatedDateRangeQuery(TIME_RANGE_OPTIONS_VALUES.ONE_MONTH),
        }),
        getNormalizedURL(this.logsIndexUrl),
        true, // clearParams
        true, // railsArraySyntax
        true, // decodeParams
      );
    },
  },
  created() {
    this.validateAndFetch();
  },
  mounted() {
    this.trackEvent(VIEW_TRACING_DETAILS_PAGE);
  },
  methods: {
    async validateAndFetch() {
      if (!this.traceId) {
        createAlert({
          message: this.$options.i18n.error,
        });
      }
      await this.fetchTrace();
    },
    async fetchTrace() {
      this.loading = true;
      try {
        const trace = await this.observabilityClient.fetchTrace(this.traceId);
        // freezing object removes reactivity and lowers memory consumption for large objects
        this.trace = Object.freeze(trace);
        this.spanTrees = Object.freeze(mapTraceToSpanTrees(this.trace));
        this.isTracePruned = this.spanTrees.pruned;
      } catch (e) {
        createAlert({
          message: this.$options.i18n.error,
        });
      } finally {
        this.loading = false;
      }
    },
    goToTracingIndex() {
      visitUrl(this.tracingIndexUrl);
    },
    onToggleDrawer({ spanId }) {
      if (this.selectedSpan?.span_id === spanId) {
        this.closeDrawer();
      } else {
        const span = this.trace.spans.find((s) => s.span_id === spanId);
        this.selectedSpan = span;
        this.isDrawerOpen = true;
      }
    },
    closeDrawer() {
      this.selectedSpan = null;
      this.isDrawerOpen = false;
    },
  },
  SPANS_LIMIT,
};
</script>

<template>
  <div v-if="loading" class="gl-py-5">
    <gl-loading-icon size="lg" />
  </div>

  <div v-else-if="trace" data-testid="trace-details" class="gl-mx-6">
    <tracing-header
      :trace="trace"
      :incomplete="spanTrees.incomplete"
      :logs-link="logsLink"
      class="gl-mb-6"
    />

    <gl-alert v-if="isTracePruned" variant="warning">
      <gl-sprintf :message="$options.i18n.prunedWarning">
        <template #totalSpans>{{ trace.spans.length }}</template>
        <template #spansLimit>{{ $options.SPANS_LIMIT }}</template>
      </gl-sprintf>
    </gl-alert>

    <tracing-chart
      :span-trees="spanTrees.roots"
      :trace="trace"
      :selected-span-id="selectedSpan && selectedSpan.span_id"
      @span-selected="onToggleDrawer"
    />

    <tracing-drawer :span="selectedSpan" :open="isDrawerOpen" @close="closeDrawer" />
  </div>
</template>
