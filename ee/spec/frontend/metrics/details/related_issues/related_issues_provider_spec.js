import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RelatedIssuesProvider from 'ee/metrics/details/related_issues/related_issues_provider.vue';
import relatedIssuesQuery from 'ee/metrics/details/related_issues/graphql/get_related_issues.query.graphql';
import { mockData } from './mock_data';

Vue.use(VueApollo);

describe('RelatedIssuesProvider component', () => {
  let defaultSlotSpy;
  let relatedIssuesQueryMock;

  const defaultProps = { projectFullPath: 'foo/bar', metricName: 'aMetric', metricType: 'aType' };

  let wrapper;

  function createComponent({ props = defaultProps, slots, queryMock } = {}) {
    relatedIssuesQueryMock = queryMock ?? jest.fn().mockResolvedValue(mockData);
    const apolloProvider = createMockApollo([[relatedIssuesQuery, relatedIssuesQueryMock]]);

    defaultSlotSpy = jest.fn();

    wrapper = shallowMountExtended(RelatedIssuesProvider, {
      apolloProvider,
      propsData: {
        ...props,
      },
      scopedSlots: slots || {
        default: defaultSlotSpy,
      },
    });
  }

  describe('rendered output', () => {
    it('renders correctly with default slot', () => {
      createComponent({ slots: { default: '<div>Test slot content</div>' } });

      expect(wrapper.html()).toContain('Test slot content');
    });

    it('does not render anything without default slot', () => {
      createComponent({ slots: {} });

      expect(wrapper.html()).toBe('');
    });
  });

  describe('graphql query is loading', () => {
    it('calls the default slots with loading = true and emits an event while query is executing', () => {
      createComponent();

      expect(defaultSlotSpy).toHaveBeenCalledWith(expect.objectContaining({ loading: true }));
    });

    it('calls the default slots with loading = false and emits an event while query is done', async () => {
      createComponent();
      await waitForPromises();

      expect(defaultSlotSpy).toHaveBeenCalledWith(expect.objectContaining({ loading: false }));
    });
  });

  describe('graphql query loaded', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('calls issues a query for related issues', () => {
      expect(relatedIssuesQueryMock).toHaveBeenCalledWith(defaultProps);
    });

    it('calls the default slots with issues', () => {
      expect(defaultSlotSpy).toHaveBeenCalledWith(
        expect.objectContaining({ issues: mockData.data.project.issues.nodes }),
      );
    });
  });

  describe('error handling', () => {
    it('calls the default slots with error = undefined if query does not fail', async () => {
      createComponent();
      await waitForPromises();

      expect(defaultSlotSpy).toHaveBeenCalledWith(expect.objectContaining({ error: null }));
    });

    it('calls the default slots with error and emits an event if query fails', async () => {
      createComponent({
        queryMock: jest.fn().mockResolvedValue({ errors: [{ message: 'GraphQL error' }] }),
      });
      await waitForPromises();

      expect(defaultSlotSpy).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.any(Error) }),
      );
    });
  });
});
