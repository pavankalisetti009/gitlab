import Vue from 'vue';
import ViolationDetailsApp from './components/compliance_violation_details_app.vue';

export const initDetailsApp = () => {
  const el = document.querySelector('#js-project-violation-details');

  if (!el) {
    return false;
  }

  const { projectPath = '/gitlab-org/gitlab-test', violationId } = el.dataset;

  return new Vue({
    el,
    name: 'ComplianceViolationDetailsRoot',
    render(createElement) {
      return createElement(ViolationDetailsApp, { props: { projectPath, violationId } });
    },
  });
};
