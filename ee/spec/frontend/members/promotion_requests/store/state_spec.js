import createState from 'ee/members/promotion_requests/store/state';
import { pagination } from '../mock_data';

describe('Promotion requests store state', () => {
  it('inits the state', () => {
    const state = createState({ pagination });
    expect(state).toEqual({ pagination });
  });
});
