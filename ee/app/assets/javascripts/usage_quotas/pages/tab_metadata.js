import { __ } from '~/locale';
import apolloProvider from '../shared/provider';
import { PAGES_TAB_METADATA_EL_SELECTOR } from '../constants';
import PagesDeploymentsApp from './components/app.vue';

export const parseProvideData = (el) => {
  const { fullPath, deploymentsLimit, deploymentsCount } = el.dataset;

  return { fullPath, deploymentsLimit, deploymentsCount };
};

export const getPagesTabMetadata = () => {
  const el = document.querySelector(PAGES_TAB_METADATA_EL_SELECTOR);

  if (!el) return false;

  return {
    title: __('Pages'),
    hash: '#pages-deployments-usage-tab',
    testid: 'pages-tab',
    component: {
      name: 'PagesDeploymentsTab',
      apolloProvider,
      provide: parseProvideData(el),
      render(createElement) {
        return createElement(PagesDeploymentsApp);
      },
    },
  };
};
