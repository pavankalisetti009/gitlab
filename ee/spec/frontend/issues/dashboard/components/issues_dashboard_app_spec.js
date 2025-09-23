import { shallowMount } from '@vue/test-utils';
import IssuesDashboardAppEE from 'ee/issues/dashboard/components/issues_dashboard_app.vue';
import IssuesDashboardApp from '~/issues/dashboard/components/issues_dashboard_app.vue';
import { TOKEN_TYPE_STATUS } from '~/vue_shared/components/filtered_search_bar/constants';

describe('IssuesDashboardAppEE component', () => {
  let wrapper;

  const findIssuesDashboardApp = () => wrapper.findComponent(IssuesDashboardApp);

  const mountComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMount(IssuesDashboardAppEE, {
      provide: {
        ...provide,
      },
    });
  };

  describe('tokens', () => {
    describe('when workItemStatusMvc2=true', () => {
      describe('when hasStatusFeature=true', () => {
        it('passes status token to IssuesDashboardApp', () => {
          mountComponent({
            provide: { hasStatusFeature: true, glFeatures: { workItemStatusMvc2: true } },
          });

          expect(findIssuesDashboardApp().props('eeSearchTokens')).toMatchObject([
            { type: TOKEN_TYPE_STATUS },
          ]);
        });
      });

      describe('when hasStatusFeature=false', () => {
        it('does not pass status token to IssuesDashboardApp', () => {
          mountComponent({
            provide: { hasStatusFeature: false, glFeatures: { workItemStatusMvc2: true } },
          });

          expect(findIssuesDashboardApp().props('eeSearchTokens')).toEqual([]);
        });
      });
    });

    describe('when workItemStatusMvc2=false', () => {
      describe('when hasStatusFeature=true', () => {
        it('does not pass status token to IssuesDashboardApp', () => {
          mountComponent({
            provide: { hasStatusFeature: true, glFeatures: { workItemStatusMvc2: false } },
          });

          expect(findIssuesDashboardApp().props('eeSearchTokens')).toEqual([]);
        });
      });

      describe('when hasStatusFeature=false', () => {
        it('does not pass status token to IssuesDashboardApp', () => {
          mountComponent({
            provide: { hasStatusFeature: false, glFeatures: { workItemStatusMvc2: false } },
          });

          expect(findIssuesDashboardApp().props('eeSearchTokens')).toEqual([]);
        });
      });
    });
  });
});
