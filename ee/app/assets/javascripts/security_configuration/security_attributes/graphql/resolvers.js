import {
  CATEGORY_EDITABLE,
  CATEGORY_PARTIALLY_EDITABLE,
  CATEGORY_LOCKED,
} from '../../components/security_attributes/constants';

/* eslint-disable @gitlab/require-i18n-strings */
export const mockSecurityAttributeCategories = [
  {
    id: 11,
    name: 'Application',
    description: 'Categorize projects by application type and technology stack.',
    templateType: null,
    securityAttributes: [
      {
        id: 1,
        name: 'Asset Track',
        description:
          'A comprehensive portfolio management system that monitors client investments and tracks asset performance across multiple markets.',
        color: '#3478C6',
      },
      {
        id: 2,
        name: 'Bank Branch',
        description:
          'A branch operations management platform that streamlines teller workflows, queue management, and daily transaction reconciliation.',
        color: '#67AD5C',
      },
      {
        id: 3,
        name: 'Capital Commit',
        description:
          'An enterprise lending solution that manages the complete lifecycle of commercial loans from application to disbursement.',
        color: '#EC6337',
      },
      {
        id: 4,
        name: 'Deposit Source',
        description:
          'A savings account management system that handles interest calculations, automatic transfers, and customer-facing deposit operations.',
        color: '#613CB1',
      },
      {
        id: 5,
        name: 'Fiscal Flow',
        description:
          'A cash management solution that optimizes liquidity forecasting and treasury operations across the banking network.',
        color: '#4994EC',
      },
      {
        id: 6,
        name: 'Ledger Link',
        description:
          'A general ledger system that maintains financial records, facilitates account reconciliation, and generates regulatory reports.',
        color: '#F6C444',
      },
      {
        id: 7,
        name: 'Vault Version',
        description:
          'A secure document management system for handling sensitive financial agreements, contracts, and compliance documentation.',
        color: '#9031AA',
      },
      {
        id: 8,
        name: 'Wealth Ware',
        description:
          'A private banking platform that provides personalized financial planning tools and investment advisory services for high-net-worth clients.',
        color: '#D63865',
      },
    ],
    multipleSelection: true,
    editableState: CATEGORY_PARTIALLY_EDITABLE,
  },
  {
    id: 12,
    name: 'Business Impact',
    description: 'Classify projects by their importance to business operations.',
    templateType: null,
    securityAttributes: [
      {
        id: 9,
        name: 'Mission Critical',
        description: 'Essential for core business functions',
        color: '#A16522',
      },
      {
        id: 10,
        name: 'Business Critical',
        description: 'Important for key business operations',
        color: '#B8802F',
      },
      {
        id: 11,
        name: 'Business Operational',
        description: 'Standard operational systems',
        color: '#CF9846',
      },
      {
        id: 12,
        name: 'Business Administrative',
        description: 'Supporting administrative functions',
        color: '#E2C07F',
      },
      {
        id: 13,
        name: 'Non-essential',
        description: 'Minimal business impact',
        color: '#F1DAAE',
      },
    ],
    multipleSelection: false,
    editableState: CATEGORY_LOCKED,
  },
  {
    id: 13,
    name: 'Business Unit',
    description: 'Organize projects by owning teams and departments.',
    templateType: null,
    securityAttributes: [],
    multipleSelection: true,
    editableState: CATEGORY_PARTIALLY_EDITABLE,
  },
  {
    id: 14,
    name: 'Exposure level',
    description: 'Tag systems based on network accessibility and exposure risk.',
    templateType: null,
    securityAttributes: [],
    multipleSelection: false,
    editableState: CATEGORY_PARTIALLY_EDITABLE,
  },
  {
    id: 15,
    name: 'Location',
    description: 'Track system hosting locations and geographic deployment.',
    templateType: null,
    securityAttributes: [
      {
        id: 14,
        name: 'Canada::Toronto',
        description: 'Distributed team coordination center for Canadian remote workforce.',
        color: '#9B1EC5',
      },
      {
        id: 15,
        name: 'Singapore::Singapore',
        description: 'Asia-Pacific regional office covering Southeast Asian operations.',
        color: '#D3875B',
      },
      {
        id: 16,
        name: 'UK::London',
        description: 'European headquarters serving UK and European markets.',
        color: '#5FC975',
      },
      {
        id: 17,
        name: 'USA::Austin',
        description:
          'Secondary engineering office focused on backend infrastructure and platform development.',
        color: '#3878C2',
      },
      {
        id: 18,
        name: 'USA::Denver',
        description:
          'Dedicated facility for infrastructure monitoring and cloud services management.',
        color: '#3878C2',
      },
      {
        id: 19,
        name: 'USA::New York',
        description: 'East Coast sales and business development operations center.',
        color: '#3878C2',
      },
      {
        id: 20,
        name: 'USA::San Francisco',
        description: 'Primary headquarters and main engineering hub in California.',
        color: '#3878C2',
      },
    ],
    multipleSelection: false,
    editableState: CATEGORY_EDITABLE,
  },
];

export const mockSecurityAttributes = mockSecurityAttributeCategories.flatMap(
  (category) => category.securityAttributes,
);

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
  Group: {
    securityAttributeCategories() {
      return {
        nodes: mockSecurityAttributeCategories,
      };
    },
    securityAttributes(_, { categoryId }) {
      return {
        nodes: mockSecurityAttributeCategories
          .filter((category) => category.id === categoryId)
          .flatMap((category) => category.securityAttributes),
      };
    },
  },
  Project: {
    securityAttributes() {
      if (!gon.features.securityContextLabels) return { nodes: [] };
      return {
        nodes: mockSecurityAttributes
          // Temporarily (for mock data), return only attributes that contain the letter p
          .filter((attribute) => attribute.name.includes('p'))
          .map((attribute) => {
            const category = mockSecurityAttributeCategories.find((c) =>
              c.securityAttributes.some((a) => a.id === attribute.id),
            );
            return {
              ...attribute,
              category: {
                id: category.id,
                name: category.name,
              },
            };
          }),
      };
    },
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
