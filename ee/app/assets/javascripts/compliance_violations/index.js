import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { __ } from '~/locale';
import createDefaultClient from '~/lib/graphql';
import ViolationDetailsApp from './components/compliance_violation_details_app.vue';
import complianceViolationQuery from './graphql/compliance_violation.query.graphql';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initDetailsApp = () => {
  const el = document.querySelector('#js-project-violation-details');

  if (!el) {
    return false;
  }

  const { violationId } = el.dataset;

  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: complianceViolationQuery,
    variables: { id: violationId },
    data: {
      complianceViolation: {
        id: 1,
        status: __('In review'),
        project: {
          id: 2,
          nameWithNamespace: 'GitLab.org / GitLab Test',
          fullPath: '/gitlab/org/gitlab-test',
          webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
        },
      },
    },
  });

  return new Vue({
    el,
    name: 'ComplianceViolationDetailsRoot',
    apolloProvider,
    render(createElement) {
      return createElement(ViolationDetailsApp, { props: { violationId } });
    },
  });
};
