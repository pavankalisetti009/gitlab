<script>
import { GlSprintf } from '@gitlab/ui';
import {
  CRITICAL,
  HIGH,
  MEDIUM,
  LOW,
  INFO,
  UNKNOWN,
  SEVERITY_COUNT_LIMIT,
} from 'ee/vulnerabilities/constants';
import { s__, sprintf } from '~/locale';

export default {
  components: {
    GlSprintf,
  },
  i18n: {
    highlights: s__(
      'ciReport|%{criticalStart}critical%{criticalEnd}, %{highStart}high%{highEnd}, and %{otherStart}others%{otherEnd}',
    ),
  },
  props: {
    /**
     * If provided, this will display only the count for the given severity.
     */
    showSingleSeverity: {
      type: String,
      required: false,
      default: '',
      validator: (severity) =>
        !severity || [CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN].includes(severity),
    },
    highlights: {
      type: Object,
      required: true,
      validator: (highlights) =>
        [CRITICAL, HIGH].every((requiredField) => {
          if (typeof highlights[requiredField] === 'undefined') {
            return true;
          }

          return Number.isInteger(highlights[requiredField]);
        }),
    },
    capped: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    criticalSeverityCount() {
      return this.formattedCounts(this.highlights[CRITICAL]);
    },
    highSeverityCount() {
      return this.formattedCounts(this.highlights[HIGH]);
    },
    otherSeverityCount() {
      if (typeof this.highlights.other !== 'undefined') {
        return this.formattedCounts(this.highlights.other);
      }

      let totalCounts = 0;
      let isCapped = false;

      [MEDIUM, LOW, INFO, UNKNOWN].forEach((severity) => {
        const count = this.highlights[severity];

        if (count) {
          totalCounts += count;
        }

        if (this.capped && count > SEVERITY_COUNT_LIMIT) {
          isCapped = true;
        }
      });

      return isCapped ? this.formattedCounts(totalCounts) : totalCounts;
    },
  },
  methods: {
    formattedCounts(count) {
      if (this.capped) {
        return count > SEVERITY_COUNT_LIMIT
          ? sprintf(s__('SecurityReports|%{count}+'), { count: SEVERITY_COUNT_LIMIT })
          : count;
      }

      return count;
    },
    component(count) {
      if (parseInt(count, 10) > 0) {
        return 'strong';
      }

      return 'span';
    },
  },
};
</script>

<template>
  <div class="gl-text-sm">
    <component
      :is="component(highlights[showSingleSeverity])"
      v-if="showSingleSeverity"
      :class="`severity-text-${showSingleSeverity}`"
      >{{ formattedCounts(highlights[showSingleSeverity]) }}
      {{ n__('vulnerability', 'vulnerabilities', highlights[showSingleSeverity]) }}</component
    >
    <gl-sprintf v-else :message="$options.i18n.highlights">
      <template #critical="{ content }"
        ><component
          :is="component(criticalSeverityCount)"
          class="severity-text-critical"
          data-testid="critical"
          >{{ criticalSeverityCount }} {{ content }}</component
        ></template
      >
      <template #high="{ content }"
        ><component :is="component(highSeverityCount)" class="severity-text-high" data-testid="high"
          >{{ highSeverityCount }} {{ content }}</component
        ></template
      >
      <template #other="{ content }"
        ><component :is="component(otherSeverityCount)" data-testid="other"
          >{{ otherSeverityCount }} {{ content }}</component
        ></template
      >
    </gl-sprintf>
  </div>
</template>
