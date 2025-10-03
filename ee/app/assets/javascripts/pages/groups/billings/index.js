import initTargetedMessages from 'ee/admin/init_targeted_message';
import { shouldQrtlyReconciliationMount } from 'ee/billings/qrtly_reconciliation';
import initSubscriptions from 'ee/billings/subscriptions';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import FreeTrialBillingApp from 'ee/groups/billing/components/app.vue';

initSubscriptions();
shouldQrtlyReconciliationMount();
initTargetedMessages();
initSimpleApp('#js-free-trial-plan-billing', FreeTrialBillingApp);
