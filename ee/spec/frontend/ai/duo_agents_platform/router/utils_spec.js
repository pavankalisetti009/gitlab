import {
  extractNavScopeFromRoute,
  activeNavigationWatcher,
  getNamespaceIndexComponent,
} from 'ee/ai/duo_agents_platform/router/utils';
import * as domUtils from 'ee/ai/duo_agents_platform/router/dom_utils';
import ProjectAgentsPlatformIndex from 'ee/ai/duo_agents_platform/namespace/project/project_agents_platform_index.vue';

describe('extractNavScopeFromRoute', () => {
  describe('when route is empty', () => {
    it('returns an empty string', () => {
      expect(extractNavScopeFromRoute({})).toBe('');
    });
  });

  describe('when the route has no matched items', () => {
    it('returns an empty string', () => {
      expect(extractNavScopeFromRoute({ matched: [] })).toBe('');
    });
  });

  describe('when t route has no multiple matched items', () => {
    it('returns an the first item path withotu hte leading', () => {
      expect(extractNavScopeFromRoute({ matched: [] })).toBe('');
    });
  });
});

describe('activeNavigationWatcher', () => {
  let to;
  let from;
  let next;

  beforeEach(() => {
    jest.spyOn(domUtils, 'updateActiveNavigation').mockImplementation(() => {});
    next = jest.fn();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('when route scopes are different', () => {
    beforeEach(() => {
      to = { matched: [{ path: '/agent-issues' }, { path: '/agent-issues/new' }] };
      from = { matched: [{ path: '/agent-sessions' }] };
      activeNavigationWatcher(to, from, next);
    });

    it('calls updateActiveNavigation with the correct scope', () => {
      expect(domUtils.updateActiveNavigation).toHaveBeenCalledWith('agent-issues');
    });

    it('calls next to continue the navigation', () => {
      expect(next).toHaveBeenCalled();
    });
  });

  describe('when no changes are detected in navigation scope', () => {
    beforeEach(() => {
      to = { matched: [{ path: '/agent-sessions' }, { path: '/agent-sessions/new' }] };
      from = { matched: [{ path: '/agent-sessions' }, { path: '/agent-sessions/existing' }] };

      activeNavigationWatcher(to, from, next);
    });

    it('does not call updateActiveNavigation', () => {
      expect(domUtils.updateActiveNavigation).not.toHaveBeenCalled();
    });

    it('still calls next to continue the navigation', () => {
      expect(next).toHaveBeenCalled();
    });
  });

  describe('when there is no previous route', () => {
    beforeEach(() => {
      to = { matched: [{ path: '/agent-issues' }, { path: '/agent-issues/new' }] };
      from = { matched: [] };
      activeNavigationWatcher(to, from, next);
    });

    it('calls updateActiveNavigation with the current scope', () => {
      expect(domUtils.updateActiveNavigation).toHaveBeenCalledWith('agent-issues');
    });

    it('calls next to continue the navigation', () => {
      expect(next).toHaveBeenCalled();
    });
  });
});

describe('getNamespaceIndexComponent', () => {
  describe('when namespace is not provided', () => {
    it('throws an error', () => {
      expect(() => getNamespaceIndexComponent()).toThrow(
        'The namespace argument must be passed to the Vue Router',
      );
    });
  });

  it.each`
    namespace    | expectedComponent
    ${'project'} | ${ProjectAgentsPlatformIndex}
    ${'group'}   | ${undefined}
    ${'unknown'} | ${undefined}
  `(
    'returns $expectedComponent when namespace is $namespace',
    ({ namespace, expectedComponent }) => {
      expect(getNamespaceIndexComponent(namespace)).toBe(expectedComponent);
    },
  );
});
