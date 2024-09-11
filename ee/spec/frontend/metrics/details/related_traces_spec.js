import { GlSprintf, GlIcon, GlLink } from '@gitlab/ui';
import { uniqueId } from 'lodash';

import RelatedTraces from 'ee/metrics/details/related_traces.vue';
import { viewTracesUrlWithMetric } from 'ee/metrics/details/utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

jest.mock('ee/metrics/details/utils', () => ({
  viewTracesUrlWithMetric: jest.fn().mockReturnValue('http://mock-path'),
}));

describe('RelatedTraces', () => {
  let wrapper;

  const mountComponent = (props) => {
    wrapper = shallowMountExtended(RelatedTraces, {
      propsData: {
        tracingIndexUrl: 'trace-index',
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findTracesList = () => wrapper.findByTestId('traces-list');
  const findTracesListItems = () => findTracesList().findAll('li');

  const createDataPoints = ({ traceIds }) => ({
    // Chart series always have unique names
    seriesName: uniqueId('app.ads.ad_request_type: NOT_TARGETED, app.ads.ad_response_type: RANDOM'),
    color: '#617ae2',
    timestamp: 1725467764487,
    value: 1234,
    traceIds,
  });

  const mockDataPoints = [
    createDataPoints({ traceIds: ['t1', 't2'] }),
    createDataPoints({ traceIds: ['t3', 't4'] }),
    createDataPoints({ traceIds: [] }),
  ];

  describe('when there are data points', () => {
    beforeEach(() => {
      mountComponent({ dataPoints: mockDataPoints });
    });

    it('renders the header text', () => {
      expect(wrapper.text()).toContain('Sep 04 2024 16:36:04 UTC');
    });

    it('renders the list of data points', () => {
      expect(findTracesListItems()).toHaveLength(mockDataPoints.length);
    });

    it('renders the data point details', () => {
      const item = findTracesListItems().at(0);

      expect(item.text()).toContain(
        'app.ads.ad_request_type: NOT_TARGETED, app.ads.ad_response_type: RANDOM',
      );
      expect(item.text()).toContain('(Value: 1234)');
      expect(item.findComponent(GlIcon).props()).toMatchObject({
        name: 'status_created',
        size: 16,
      });
    });

    it('renders the link when there are traces', () => {
      const item = findTracesListItems().at(0);

      expect(viewTracesUrlWithMetric).toHaveBeenCalledWith('trace-index', mockDataPoints[0]);

      expect(item.findComponent(GlLink).attributes('href')).toBe('http://mock-path');
    });

    it('renders a message when a data point has not related traces', () => {
      const item = findTracesListItems().at(2);

      expect(item.text()).toContain('No related traces');
    });
  });

  describe('when there are no trace IDs in the data points', () => {
    beforeEach(() => {
      mountComponent({
        dataPoints: [createDataPoints({ traceIds: [] })],
      });
    });

    it('does not render the list of data points', () => {
      expect(findTracesList().exists()).toBe(false);
    });

    it('renders the empty state', () => {
      expect(wrapper.text()).toContain(
        'No related traces for the selected time. Select another data point and try again.',
      );
    });
  });

  describe('when there are no data points', () => {
    beforeEach(() => {
      mountComponent({
        dataPoints: [],
      });
    });

    it('does not render the widget', () => {
      expect(wrapper.html()).toBe('');
    });
  });
});
