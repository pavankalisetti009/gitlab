import Vue from 'vue';
import { GlToast } from '@gitlab/ui';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import FeatureSettingsApp from './components/app.vue';

Vue.use(GlToast);

initSimpleApp('#js-ai-powered-features', FeatureSettingsApp, { withApolloProvider: true });
