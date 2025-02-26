import * as getters from 'ee/usage_quotas/seats/store/getters';
import State from 'ee/usage_quotas/seats/store/state';

describe('Usage Quotas Seats getters', () => {
  let state;

  beforeEach(() => {
    state = State();
  });

  describe('isLoading', () => {
    beforeEach(() => {
      state.isLoadingBillableMembers = false;
      state.isLoadingGitlabSubscription = false;
      state.isChangingMembershipState = false;
    });

    it('returns false if nothing is being loaded', () => {
      expect(getters.isLoading(state)).toBe(false);
    });

    it.each([
      'isLoadingBillableMembers',
      'isLoadingGitlabSubscription',
      'isChangingMembershipState',
    ])('returns true if %s is being loaded', (key) => {
      state[key] = true;

      expect(getters.isLoading(state)).toBe(true);
    });
  });
});
