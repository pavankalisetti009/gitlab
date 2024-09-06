import {
  subscribe,
  invalidate,
} from 'ee/members/promotion_requests/services/promotion_request_list_invalidation_service';

describe('Promotion request list invalidation service', () => {
  const callback = jest.fn();
  let unsubscribe;

  beforeEach(() => {
    unsubscribe = subscribe(callback);
  });

  afterEach(() => {
    unsubscribe();
  });

  it('does not execute the callback when the service is not invalidated', () => {
    expect(callback).not.toHaveBeenCalled();
  });

  it('subscribes to the service', () => {
    invalidate();

    expect(callback).toHaveBeenCalledTimes(1);
  });

  it('unsubscribes from the service', () => {
    unsubscribe();
    invalidate();

    expect(callback).not.toHaveBeenCalled();
  });
});
