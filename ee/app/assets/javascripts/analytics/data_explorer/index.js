import Vue from 'vue';
import DataExplorerApp from './components/app.vue';

export default () => {
  const el = document.querySelector('#js-data-explorer-app');
  if (!el) return false;

  return new Vue({
    el,
    name: 'DataExplorerApp',
    render: (createElement) => createElement(DataExplorerApp),
  });
};
