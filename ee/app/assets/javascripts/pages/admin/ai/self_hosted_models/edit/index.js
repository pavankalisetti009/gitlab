import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import EditSelfHostedModel from '../components/edit_self_hosted_model.vue';

initSimpleApp('#js-edit-self-hosted-model', EditSelfHostedModel, { withApolloProvider: true });
