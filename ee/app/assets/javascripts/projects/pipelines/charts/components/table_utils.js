import { formatNumber } from '~/locale';
import { formatPipelineDuration } from '~/projects/pipelines/charts/format_utils';

export const numericField = () => ({
  thClass: 'gl-text-right',
  tdClass: 'gl-text-right',
  thAlignRight: true,
  sortable: true,
  formatter: (n) =>
    formatNumber(n, {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }),
});

export const durationField = () => ({
  ...numericField(),
  formatter: formatPipelineDuration,
});
