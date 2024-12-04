<script>
import {
  GlLink,
  GlIcon,
  GlTooltipDirective,
  GlButton,
  GlProgressBar,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { isNil } from 'lodash';
import { formatNumber } from '~/locale';

export default {
  name: 'StatisticsCard',
  components: { GlLink, GlIcon, GlButton, GlProgressBar, GlSkeletonLoader },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    usageValue: {
      type: [Number, String],
      required: false,
      default: null,
    },
    usageUnit: {
      type: String,
      required: false,
      default: null,
    },
    totalValue: {
      type: [Number, String],
      required: false,
      default: null,
    },
    totalUnit: {
      type: String,
      required: false,
      default: null,
    },
    summaryDataTestid: {
      type: String,
      required: false,
      default: 'denominator',
    },
    description: {
      type: String,
      required: false,
      default: null,
    },
    helpLink: {
      type: String,
      required: false,
      default: null,
    },
    helpLabel: {
      type: String,
      required: false,
      default: null,
    },
    helpTooltip: {
      type: String,
      required: false,
      default: null,
    },
    percentage: {
      type: Number,
      required: false,
      default: null,
    },
    purchaseButtonLink: {
      type: String,
      required: false,
      default: null,
    },
    purchaseButtonText: {
      type: String,
      required: false,
      default: null,
    },
    cssClass: {
      type: String,
      required: false,
      default: null,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  methods: {
    isNil,
    formatValue(input) {
      return Number.isInteger(input) ? formatNumber(input) : input;
    },
  },
};
</script>

<template>
  <div
    class="gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-bg-white gl-p-6"
    data-testid="container"
    :class="cssClass"
  >
    <div v-if="loading" class="lg:gl-w-1/2">
      <gl-skeleton-loader :height="50">
        <rect width="140" height="30" x="5" y="0" rx="4" />
        <rect width="240" height="10" x="5" y="40" rx="4" />
      </gl-skeleton-loader>
    </div>
    <template v-else>
      <div class="gl-flex gl-justify-between">
        <p
          v-if="!isNil(usageValue) && usageValue !== ''"
          class="gl-mb-3 gl-text-size-h-display gl-font-bold"
          :data-testid="summaryDataTestid"
        >
          {{ formatValue(usageValue) }}
          <span v-if="usageUnit" data-testid="denominator-usage-unit" class="gl-text-lg">{{
            usageUnit
          }}</span>
          <span v-if="totalValue" data-testid="denominator-total">
            /
            {{ formatValue(totalValue) }}
            <span v-if="totalUnit" class="gl-text-lg" data-testid="denominator-total-unit">{{
              totalUnit
            }}</span>
          </span>
        </p>

        <div>
          <gl-button
            v-if="purchaseButtonLink && purchaseButtonText"
            :href="purchaseButtonLink"
            category="primary"
            variant="confirm"
          >
            {{ purchaseButtonText }}
          </gl-button>
        </div>
      </div>
      <p v-if="description" class="gl-mb-0 gl-font-bold" data-testid="description">
        {{ description }}
        <gl-link
          v-if="helpLink"
          v-gl-tooltip
          :href="helpLink"
          target="_blank"
          class="gl-ml-2"
          :title="helpTooltip"
          :aria-label="helpLabel"
        >
          <gl-icon name="question-o" />
        </gl-link>
      </p>
      <gl-progress-bar v-if="percentage !== null" class="gl-mt-5" :value="percentage" />
    </template>
  </div>
</template>
