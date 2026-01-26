import { shouldQrtlyReconciliationMount } from 'ee/billings/qrtly_reconciliation';
import initSubscriptions from 'ee/billings/subscriptions';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import FreeTrialBillingApp from 'ee/groups/billing/components/app.vue';
import TargetedMessageBanner from 'ee/targeted_message_banner/components/index.vue';

initSimpleApp('#js-targeted-message-banner', TargetedMessageBanner, { withApolloProvider: true });
initSubscriptions();
shouldQrtlyReconciliationMount();
initSimpleApp('#js-free-trial-plan-billing', FreeTrialBillingApp);
