import Vue from 'vue';
import DashboardComponent from 'ee/operations/components/dashboard/dashboard.vue';
import createStore from 'ee/vue_shared/dashboards/store';

const el = document.getElementById('js-operations');

const {
  listPath,
  addPath,
  emptyDashboardSvgPath,
  emptyDashboardHelpPath,
  operationsDashboardHelpPath,
} = el.dataset;

// eslint-disable-next-line no-new
new Vue({
  el: '#js-operations',
  name: 'DashboardComponentRoot',
  store: createStore(),
  components: {
    DashboardComponent,
  },
  render(createElement) {
    return createElement(DashboardComponent, {
      props: {
        listPath,
        addPath,
        emptyDashboardSvgPath,
        emptyDashboardHelpPath,
        operationsDashboardHelpPath,
      },
    });
  },
});
