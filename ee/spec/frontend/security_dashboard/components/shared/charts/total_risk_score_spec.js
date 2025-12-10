import { nextTick } from 'vue';
import { GlChart } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import TotalRiskScore from 'ee/security_dashboard/components/shared/charts/total_risk_score.vue';

describe('TotalRiskScore chart', () => {
  let wrapper;

  const DEFAULT_SCORE = 72;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(TotalRiskScore, {
      propsData: {
        score: DEFAULT_SCORE,
        ...props,
      },
      directives: {
        GlResizeObserver: createMockDirective('gl-resize-observer'),
      },
    });
  };

  const findGlChart = () => wrapper.findComponent(GlChart);
  const getSeries = () => findGlChart().props('options').series;
  const getOuterMeterSeries = () => getSeries()[0];
  const getProgressMeterSeries = () => getSeries()[1];

  it('renders GlChart responsively', () => {
    createComponent();

    expect(findGlChart().props()).toMatchObject({
      responsive: true,
      height: 'auto',
    });
  });

  describe('outer meter ring', () => {
    it('configures a gauge with the correct dimensions', () => {
      createComponent();

      expect(getOuterMeterSeries()).toMatchObject({
        type: 'gauge',
        startAngle: 220,
        endAngle: -40,
        min: 0,
        max: 100,
        splitNumber: 4,
        center: ['50%', '60%'],
      });
    });

    it('configures the outer meter ring with the correct colors', () => {
      createComponent();

      expect(getOuterMeterSeries().axisLine.lineStyle.color).toEqual([
        [0.25, 'var(--risk-score-color-low)'],
        [0.5, 'var(--risk-score-color-medium)'],
        [0.75, 'var(--risk-score-color-high)'],
        [1, 'var(--risk-score-color-critical)'],
      ]);
    });

    it.each`
      givenScore | expectedLabel      | expectedColor
      ${1}       | ${'Low risk'}      | ${'var(--risk-score-gauge-text-low)'}
      ${26}      | ${'Medium risk'}   | ${'var(--risk-score-gauge-text-medium)'}
      ${51}      | ${'High risk'}     | ${'var(--risk-score-gauge-text-high)'}
      ${76}      | ${'Critical risk'} | ${'var(--risk-score-gauge-text-critical)'}
    `(
      'when the score is "$givenScore", the outer meter ring has the correct title and detail colors',
      ({ givenScore, expectedLabel, expectedColor }) => {
        createComponent({ score: givenScore });

        const outerSeries = getOuterMeterSeries();

        expect(outerSeries.title.color).toBe(expectedColor);
        expect(outerSeries.detail.color).toBe(expectedColor);
        expect(outerSeries.data[0].name).toBe(expectedLabel);
      },
    );
  });

  describe('progress meter ring', () => {
    it('passes the correct data to the progress meter ring', () => {
      createComponent();

      expect(getProgressMeterSeries().data).toEqual([{ value: DEFAULT_SCORE }]);
    });

    it('configures the progress meter ring with the correct dimensions', () => {
      createComponent();

      expect(getProgressMeterSeries()).toMatchObject({
        type: 'gauge',
        startAngle: 220,
        endAngle: -40,
        min: 0,
        max: 100,
      });
    });

    it.each`
      givenScore | expectedColor
      ${1}       | ${'var(--risk-score-color-low)'}
      ${26}      | ${'var(--risk-score-color-medium)'}
      ${51}      | ${'var(--risk-score-color-high)'}
      ${76}      | ${'var(--risk-score-color-critical)'}
    `(
      'when the score is "$givenScore", the progress meter ring has the correct color',
      ({ givenScore, expectedColor }) => {
        createComponent({ score: givenScore });

        const progressSeries = getProgressMeterSeries();

        expect(progressSeries.axisLine.lineStyle.color[0][0]).toEqual(givenScore / 100);
        expect(progressSeries.axisLine.lineStyle.color[0][1]).toEqual(expectedColor);
      },
    );
  });

  describe('chart resizing', () => {
    it.each`
      givenChartWidth | givenChartHeight | expectedOuterRingWidth | expectedProgressRingWidth | expectedOuterRingRadius | expectedProgressRingRadius
      ${400}          | ${200}           | ${15}                  | ${30}                     | ${80}                   | ${64}
      ${200}          | ${100}           | ${8}                   | ${16}                     | ${40}                   | ${31}
      ${2000}         | ${1000}          | ${15}                  | ${30}                     | ${400}                  | ${384}
    `(
      'given a chart width of "$givenChartWidth" and a chart height of "$givenChartHeight", the chart is showing the correct ring widths and radii',
      async ({
        givenChartWidth,
        givenChartHeight,
        expectedOuterRingWidth,
        expectedProgressRingWidth,
        expectedOuterRingRadius,
        expectedProgressRingRadius,
      }) => {
        createComponent();

        const resizeObserverEntry = {
          contentRect: { width: givenChartWidth, height: givenChartHeight },
        };
        getBinding(wrapper.element, 'gl-resize-observer').value(resizeObserverEntry);
        await nextTick();

        const outerSeries = getOuterMeterSeries();
        const progressSeries = getProgressMeterSeries();

        expect(outerSeries.axisLine.lineStyle.width).toBe(expectedOuterRingWidth);
        expect(progressSeries.axisLine.lineStyle.width).toBe(expectedProgressRingWidth);

        expect(outerSeries.radius).toBe(expectedOuterRingRadius);
        expect(progressSeries.radius).toBe(expectedProgressRingRadius);
      },
    );
  });
});
