/* eslint-disable @gitlab/require-i18n-strings */

// Store for tracked refs (simulating cache)
// Initialize with default mock data
let trackedRefsStore = [
  {
    __typename: 'LocalTrackedRef',
    id: 'gid://gitlab/TrackedRef/1',
    name: 'master',
    refType: 'BRANCH',
    isDefault: true,
    isProtected: true,
    commit: {
      __typename: 'LocalTrackedCommit',
      sha: 'df210850abc123',
      shortId: 'df21085',
      title: 'Apply 1 suggestion(s) to 1 file(s)',
      authoredDate: '2025-10-20T09:59:00Z',
      webPath: '/project/-/commit/df21085',
    },
    vulnerabilitiesCount: 258,
  },
  {
    __typename: 'LocalTrackedRef',
    id: 'gid://gitlab/TrackedRef/2',
    name: 'main-update-small',
    refType: 'BRANCH',
    isDefault: false,
    isProtected: true,
    commit: {
      __typename: 'LocalTrackedCommit',
      sha: '693bb5e6abc456',
      shortId: '693bb5e6',
      title: 'Update VERSION files',
      authoredDate: '2025-10-15T14:30:00Z',
      webPath: '/project/-/commit/693bb5e6',
    },
    vulnerabilitiesCount: 5,
  },
];

/* eslint-disable @gitlab/require-i18n-strings */
export default {
  Project: {
    securityTrackedRefs(_, { first, after }) {
      const PAGE_SIZE = first || 3;

      return new Promise((resolve, reject) => {
        // Simulate an error if the URL contains 'error'
        if (document.location.search.includes('error')) {
          reject(new Error('Failed to load tracked refs.'));
        }

        setTimeout(() => {
          // Use the tracked refs store
          const allTrackedRefs = trackedRefsStore || [];
          const totalCount = allTrackedRefs.length;

          // Hardcoded pagination for two pages so we can mock the pagination and simulate it in the UI until the BE is ready
          let nodes;
          let hasNextPage;
          let hasPreviousPage;
          let startCursor;
          let endCursor;

          if (after === 'page1') {
            nodes = allTrackedRefs.slice(PAGE_SIZE, PAGE_SIZE * 2);
            hasNextPage = totalCount > PAGE_SIZE * 2;
            hasPreviousPage = true;
            startCursor = 'page1';
            endCursor = 'page1';
          } else {
            nodes = allTrackedRefs.slice(0, PAGE_SIZE);
            hasNextPage = totalCount > PAGE_SIZE;
            hasPreviousPage = false;
            startCursor = null;
            endCursor = 'page1';
          }

          const pageInfo = {
            __typename: 'LocalPageInfo',
            hasNextPage,
            hasPreviousPage,
            startCursor,
            endCursor,
          };

          resolve({
            __typename: 'LocalTrackedRefConnection',
            nodes,
            pageInfo,
            count: totalCount,
          });
        }, 1000);
      });
    },
  },
  Mutation: {
    securityTrackedRefsUntrack(_, { input }) {
      const { refIds } = input;
      if (document.location.search.includes('untrackError')) {
        return {
          __typename: 'SecurityTrackedRefsUntrackPayload',
          errors: ['Failed to untrack refs.'],
          untrackedRefIds: [],
        };
      }

      if (trackedRefsStore) {
        trackedRefsStore = trackedRefsStore.filter((ref) => !refIds.includes(ref.id));
      }

      return {
        __typename: 'SecurityTrackedRefsUntrackPayload',
        errors: [],
        untrackedRefIds: refIds,
      };
    },
    securityTrackedRefsTrack(_, { input }) {
      const { refs } = input;

      if (document.location.search.includes('trackError')) {
        return {
          __typename: 'SecurityTrackedRefsTrackPayload',
          errors: ['Failed to track refs.'],
          trackedRefs: [],
        };
      }

      // Transform input refs to full LocalTrackedRef format
      const trackedRefs = refs.map((ref) => ({
        __typename: 'LocalTrackedRef',
        id: `gid://gitlab/TrackedRef/${ref.refType.toLowerCase()}-${ref.name}`,
        name: ref.name,
        refType: ref.refType,
        isDefault: false,
        isProtected: ref.isProtected || false,
        commit: ref.commit
          ? {
              __typename: 'LocalTrackedCommit',
              ...ref.commit,
            }
          : null,
        vulnerabilitiesCount: 0,
      }));

      // Add to store if it exists
      if (trackedRefsStore) {
        trackedRefsStore = [...trackedRefsStore, ...trackedRefs];
      } else {
        trackedRefsStore = trackedRefs;
      }

      return {
        __typename: 'SecurityTrackedRefsTrackPayload',
        errors: [],
        trackedRefs,
      };
    },
  },
};
/* eslint-enable @gitlab/require-i18n-strings */
