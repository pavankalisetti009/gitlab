import { initTrialCreateLeadForm } from 'ee/trials/init_create_lead_form';
import { trackSaasTrialSubmit } from 'ee/google_tag_manager';
import { initNamespaceSelector } from 'ee/trials/init_namespace_selector';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import CreateTrialForm from 'ee/trials/components/create_trial_form.vue';

trackSaasTrialSubmit('.js-saas-duo-pro-trial-group', 'saasDuoProTrialGroup');
initTrialCreateLeadForm('saasDuoProTrialSubmit');
initSimpleApp('#js-create-trial-form', CreateTrialForm, { withApolloProvider: apolloProvider });
initNamespaceSelector();
