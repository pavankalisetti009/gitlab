import { FLOW_TRIGGER_TYPE_ASSIGN_REVIEWER } from 'ee/ai/duo_agents_platform/constants';

export const ASSIGN_REVIEWER_USERS_QUERY_VARIABLES = {
  includeServiceAccountsForTriggerEvents: [FLOW_TRIGGER_TYPE_ASSIGN_REVIEWER.graphQL],
};
