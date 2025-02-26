import { PLAN_CODE_FREE } from 'ee/usage_quotas/seats/constants';

export const isLoading = (state) =>
  state.isLoadingBillableMembers ||
  state.isLoadingGitlabSubscription ||
  state.isChangingMembershipState;
export const hasFreePlan = ({ planCode }) => planCode === PLAN_CODE_FREE;
