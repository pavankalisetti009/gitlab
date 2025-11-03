import {
  getLastRouteState,
  saveRouteState,
  clearRouteState,
  restoreLastRoute,
  setupNavigationGuards,
  getStorageKey,
} from 'ee/ai/duo_agents_platform/utils/navigation_state';
import { getStorageValue, saveStorageValue, removeStorageValue } from '~/lib/utils/local_storage';

jest.mock('~/lib/utils/local_storage');

describe('Navigation State Utils', () => {
  const mockRoute = {
    name: 'agents_platform_show_route',
    params: { id: '123' },
    path: '/agent-sessions/123',
  };
  const mockRouteState = {
    name: 'agents_platform_show_route',
    params: { id: '123' },
  };
  const mockRouter = { push: jest.fn(), afterEach: jest.fn() };
  const defaultStorageKey = 'duo_agents_platform_last_route';

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getStorageKey', () => {
    it.each([
      { context: undefined, expected: defaultStorageKey, description: 'when no context provided' },
      { context: null, expected: defaultStorageKey, description: 'when context is null' },
      {
        context: 'custom_context',
        expected: `${defaultStorageKey}_custom_context`,
        description: 'when context provided',
      },
    ])('returns $expected $description', ({ context, expected }) => {
      expect(getStorageKey(context)).toBe(expected);
    });
  });

  describe('getLastRouteState', () => {
    it.each([
      { exists: true, value: mockRouteState, expected: mockRouteState },
      { exists: false, expected: null },
    ])('returns $expected when storage exists: $exists', ({ exists, value, expected }) => {
      getStorageValue.mockReturnValue({ exists, value });

      expect(getLastRouteState()).toBe(expected);
      expect(getStorageValue).toHaveBeenCalledWith(defaultStorageKey);
    });
  });

  describe('saveRouteState', () => {
    it.each([
      {
        name: 'saves route state to localStorage when route has name',
        route: mockRoute,
        storageKey: undefined,
        expectedKey: defaultStorageKey,
        expectedValue: mockRouteState,
      },
      {
        name: 'saves route state with custom storage key',
        route: mockRoute,
        storageKey: 'custom_key',
        expectedKey: 'custom_key',
        expectedValue: mockRouteState,
      },
      {
        name: 'saves route state with empty params when params are undefined',
        route: { name: 'test_route', path: '/test' },
        storageKey: undefined,
        expectedKey: defaultStorageKey,
        expectedValue: { name: 'test_route', params: {} },
      },
    ])('$name', ({ route, storageKey, expectedKey, expectedValue }) => {
      saveRouteState(route, storageKey);
      expect(saveStorageValue).toHaveBeenCalledWith(expectedKey, expectedValue);
    });

    it('does not save when route has no name', () => {
      const routeWithoutName = { params: { id: '123' }, path: '/agent-sessions/123' };

      saveRouteState(routeWithoutName);
      expect(saveStorageValue).not.toHaveBeenCalled();
    });
  });

  describe('clearRouteState', () => {
    it('removes session ID from localStorage', () => {
      clearRouteState();
      expect(removeStorageValue).toHaveBeenCalledWith(defaultStorageKey);
    });
  });

  describe('restoreLastRoute', () => {
    describe('successful navigation', () => {
      beforeEach(() => {
        mockRouter.push.mockResolvedValue();
      });

      describe('with saved route', () => {
        beforeEach(() => {
          getStorageValue.mockReturnValue({
            exists: true,
            value: mockRouteState,
          });
        });

        it('navigates to saved route with default storage key', async () => {
          await restoreLastRoute(mockRouter, {});

          expect(getStorageValue).toHaveBeenCalledWith(defaultStorageKey);
          expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        });

        it('navigates to saved route with custom storage key', async () => {
          await restoreLastRoute(mockRouter, { storageKey: 'custom_key' });

          expect(getStorageValue).toHaveBeenCalledWith('custom_key');
          expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        });

        it('navigates to saved route with custom context', async () => {
          await restoreLastRoute(mockRouter, { context: 'custom_context' });

          expect(getStorageValue).toHaveBeenCalledWith(`${defaultStorageKey}_custom_context`);
          expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        });
      });

      describe('without saved route', () => {
        beforeEach(() => {
          getStorageValue.mockReturnValue({
            exists: false,
            value: null,
          });
        });

        it('navigates to default route', async () => {
          await restoreLastRoute(mockRouter, {});

          expect(getStorageValue).toHaveBeenCalledWith(defaultStorageKey);
          expect(mockRouter.push).toHaveBeenCalledWith({ name: 'agents_platform_index_route' });
        });

        it('navigates to custom default route when specified', async () => {
          await restoreLastRoute(mockRouter, { defaultRoute: 'custom_route' });

          expect(getStorageValue).toHaveBeenCalledWith(defaultStorageKey);
          expect(mockRouter.push).toHaveBeenCalledWith({ name: 'custom_route' });
        });
      });
    });

    describe('failed navigation', () => {
      beforeEach(() => {
        getStorageValue.mockReturnValue({ exists: true, value: mockRouteState });
        mockRouter.push.mockRejectedValueOnce(new Error('Navigation failed'));
        mockRouter.push.mockResolvedValueOnce();
      });

      it('falls back to default route when navigation to saved route fails', async () => {
        await restoreLastRoute(mockRouter, {});

        expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        expect(mockRouter.push).toHaveBeenCalledWith({ name: 'agents_platform_index_route' });
        expect(removeStorageValue).toHaveBeenCalledWith(defaultStorageKey);
      });

      it('falls back to default route when navigation fails with custom context', async () => {
        await restoreLastRoute(mockRouter, { context: 'text_context' });

        expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        expect(mockRouter.push).toHaveBeenCalledWith({ name: 'agents_platform_index_route' });
        expect(removeStorageValue).toHaveBeenCalledWith(`${defaultStorageKey}_text_context`);
      });

      it('falls back to custom default route when naviagtion fails', async () => {
        await restoreLastRoute(mockRouter, { defaultRoute: 'custom_route' });

        expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        expect(mockRouter.push).toHaveBeenCalledWith({ name: 'custom_route' });
        expect(removeStorageValue).toHaveBeenCalledWith(defaultStorageKey);
      });
    });
  });

  describe('setupNavigationGuards', () => {
    const setupGuard = (options = {}) => {
      setupNavigationGuards({
        router: mockRouter,
        ...options,
      });
      return mockRouter.afterEach.mock.calls[0][0];
    };

    it('sets up afterEach guard', () => {
      setupGuard();
      expect(mockRouter.afterEach).toHaveBeenCalledWith(expect.any(Function));
    });

    describe('guard behavior', () => {
      let guardFunction;

      beforeEach(() => {
        guardFunction = setupGuard();
      });

      it('saves route state when called', () => {
        guardFunction(mockRoute);
        expect(saveStorageValue).toHaveBeenCalledWith(defaultStorageKey, mockRouteState);
      });

      it('saves route state for routes outside agent sessions', () => {
        const otherRoute = { name: 'other_route', params: { id: '123' }, path: '/other-path/123' };
        const expectedState = { name: 'other_route', params: { id: '123' } };

        guardFunction(otherRoute);
        expect(saveStorageValue).toHaveBeenCalledWith(defaultStorageKey, expectedState);
      });
    });

    describe('configuration options', () => {
      it.each([
        {
          name: 'uses custom context storage key for custom context',
          options: { context: 'test_context' },
          expectedKey: `${defaultStorageKey}_test_context`,
        },
        {
          name: 'uses custom storage key when provided',
          options: { storageKey: 'custom_session_key' },
          expectedKey: 'custom_session_key',
        },
        {
          name: 'uses default storage key by default',
          options: {},
          expectedKey: defaultStorageKey,
        },
      ])('$name', ({ options, expectedKey }) => {
        const guardFunction = setupGuard(options);

        guardFunction(mockRoute);

        expect(saveStorageValue).toHaveBeenCalledWith(expectedKey, mockRouteState);
      });
    });
  });
});
