import { isLoggedIn } from '~/lib/utils/common_utils';
import { createRouter } from 'ee/ai/catalog/router';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_RUN_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
} from 'ee/ai/catalog/router/constants';

jest.mock('~/lib/utils/common_utils');

describe('AI Catalog Router', () => {
  let router;
  let mockNext;

  beforeEach(() => {
    router = createRouter('/ai-catalog');
    mockNext = jest.fn();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('route guards', () => {
    const protectedRoutes = [
      AI_CATALOG_AGENTS_NEW_ROUTE,
      AI_CATALOG_FLOWS_NEW_ROUTE,
      AI_CATALOG_AGENTS_EDIT_ROUTE,
      AI_CATALOG_AGENTS_RUN_ROUTE,
      AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
      AI_CATALOG_FLOWS_EDIT_ROUTE,
    ];

    describe('when user is authenticated', () => {
      beforeEach(() => {
        isLoggedIn.mockReturnValue(true);
      });

      it.each(protectedRoutes)('allows access to %s route', (routeName) => {
        const route = router.options.routes
          .flatMap((r) => [r, ...(r.children || [])])
          .flatMap((r) => [r, ...(r.children || [])])
          .find((r) => r.name === routeName);

        expect(route).toBeDefined();

        if (route.beforeEnter) {
          route.beforeEnter({}, {}, mockNext);
          expect(mockNext).toHaveBeenCalledWith();
        }
      });
    });

    describe('when user is not authenticated', () => {
      beforeEach(() => {
        isLoggedIn.mockReturnValue(false);
      });

      it.each(protectedRoutes)('redirects to agents route from %s', (routeName) => {
        const route = router.options.routes
          .flatMap((r) => [r, ...(r.children || [])])
          .flatMap((r) => [r, ...(r.children || [])])
          .find((r) => r.name === routeName);

        expect(route).toBeDefined();

        if (route.beforeEnter) {
          route.beforeEnter({}, {}, mockNext);
          expect(mockNext).toHaveBeenCalledWith({ name: AI_CATALOG_AGENTS_ROUTE });
        }
      });
    });
  });

  describe('public routes', () => {
    const publicRoutes = [AI_CATALOG_AGENTS_ROUTE];

    it.each(publicRoutes)('allows access to %s route regardless of authentication', (routeName) => {
      const route = router.options.routes
        .flatMap((r) => [r, ...(r.children || [])])
        .find((r) => r.name === routeName);

      expect(route).toBeDefined();
      expect(route.beforeEnter).toBeUndefined();
    });
  });
});
