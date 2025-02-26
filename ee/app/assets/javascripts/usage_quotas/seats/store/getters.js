export const isLoading = (state) =>
  state.isLoadingBillableMembers ||
  state.isLoadingGitlabSubscription ||
  state.isChangingMembershipState;
