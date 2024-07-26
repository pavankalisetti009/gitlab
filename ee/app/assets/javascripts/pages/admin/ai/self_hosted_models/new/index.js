import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import NewSelfHostedModel from '../components/new_self_hosted_model.vue';

initSimpleApp('#js-new-self-hosted-model', NewSelfHostedModel, { withApolloProvider: true });
