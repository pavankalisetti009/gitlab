import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import waitForPromises from 'helpers/wait_for_promises';
import { createRouter } from 'ee/ai/duo_agents_platform/router/ai_panel_router';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';

jest.mock('ee/ai/events/panel');
jest.mock('ee/ai/duo_agents_platform/utils/navigation_state', () => ({
  getStorageKey: jest.fn(),
  restoreLastRoute: jest.fn(),
  saveRouteState: jest.fn(),
  setupNavigationGuards: jest.fn(),
  trackTabRoutes: jest.fn(),
}));

describe('ai panel router', () => {
  let eventHandler;
  let router;

  beforeEach(() => {
    eventHub.$on.mockImplementation((event, handler) => {
      eventHandler = handler;
    });
    router = createRouter('/project', 'panel');
  });

  it('listens for SHOW_SESSION events', () => {
    expect(eventHub.$on).toHaveBeenCalledWith(SHOW_SESSION, expect.any(Function));
  });

  it('pushes the show session route with the provided id', async () => {
    const id = '5';
    eventHandler({ id });

    await waitForPromises();

    expect(router.currentRoute.name).toBe(AGENTS_PLATFORM_SHOW_ROUTE);
    expect(router.currentRoute.params).toEqual({ id });
  });
});
