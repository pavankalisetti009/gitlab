export const violationId = '123';
export const complianceCenterPath = 'mock/compliance-center';

export const mockComplianceViolation = {
  id: `gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/${violationId}`,
  status: 'IN_REVIEW',
  createdAt: '2025-06-16T02:20:41Z',
  complianceControl: {
    id: 'gid://gitlab/ComplianceManagement::ComplianceControl/1',
    name: 'Test Control',
    complianceRequirement: {
      id: 'gid://gitlab/ComplianceManagement::ComplianceRequirement/1',
      name: 'Test Requirement',
      framework: {
        id: 'gid://gitlab/ComplianceManagement::Framework/1',
        color: '#1f75cb',
        default: false,
        name: 'Test Framework',
        description: 'Test framework description',
      },
    },
  },
  issues: {
    nodes: [
      {
        id: '1',
        iid: '1',
        reference: '#1',
        referencePath: 'gitlab-org/gitlab-test#1',
        state: 'opened',
        title: 'Test',
        webUrl: 'https://localhost:3000/gitlab/org/gitlab-test/-/issues/1',
      },
    ],
  },
  project: {
    id: 'gid://gitlab/Project/2',
    nameWithNamespace: 'GitLab.org / GitLab Test',
    fullPath: '/gitlab/org/gitlab-test',
    webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
    __typename: 'Project',
  },
  auditEvent: {
    id: 'gid://gitlab/AuditEvents::ProjectAuditEvent/467',
    eventName: 'merge_request_merged',
    targetId: '2',
    targetType: 'MergeRequest',
    details: '{}',
    ipAddress: '123.1.1.9',
    entityPath: 'gitlab-org/gitlab-test',
    entityId: '2',
    entityType: 'Project',
    createdAt: '2023-01-01T00:00:00Z',
    author: {
      id: 'gid://gitlab/User/1',
      name: 'John Doe',
    },
    project: {
      id: 'gid://gitlab/Project/2',
      name: 'Test project',
      fullPath: 'gitlab-org/gitlab-test',
      webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
    },
    group: null,
    user: {
      id: 'gid://gitlab/User/1',
      name: 'John Doe',
    },
  },
  notes: {
    nodes: [
      {
        id: 'gid://gitlab/Note/1',
        body: 'Status changed to resolved',
        bodyHtml: '<p>Status changed to resolved</p>',
        createdAt: '2025-06-17T10:00:00Z',
        lastEditedAt: null,
        lastEditedBy: null,
        author: {
          id: 'gid://gitlab/User/1',
          avatarUrl: 'https://example.com/avatar.png',
          name: 'Test User',
          username: 'testuser',
          webUrl: 'https://example.com/testuser',
          webPath: '/testuser',
          __typename: 'UserCore',
        },
        discussion: {
          id: 'gid://gitlab/Discussion/1',
          __typename: 'Discussion',
        },
        systemNoteIconName: 'status',
        system: true,
        internal: false,
        __typename: 'Note',
      },
      {
        id: 'gid://gitlab/Note/2',
        body: 'Violation reviewed',
        bodyHtml: '<p>Violation reviewed</p>',
        createdAt: '2025-06-16T15:30:00Z',
        lastEditedAt: '2025-06-16T16:00:00Z',
        lastEditedBy: {
          id: 'gid://gitlab/User/2',
          avatarUrl: 'https://example.com/avatar2.png',
          name: 'Test User 2',
          username: 'testuser2',
          webUrl: 'https://example.com/testuser2',
          webPath: '/testuser2',
          __typename: 'UserCore',
        },
        author: {
          id: 'gid://gitlab/User/2',
          avatarUrl: 'https://example.com/avatar2.png',
          name: 'Test User 2',
          username: 'testuser2',
          webUrl: 'https://example.com/testuser2',
          webPath: '/testuser2',
          __typename: 'UserCore',
        },
        discussion: {
          id: 'gid://gitlab/Discussion/2',
          __typename: 'Discussion',
        },
        systemNoteIconName: null,
        system: false,
        internal: false,
        __typename: 'Note',
      },
    ],
    __typename: 'NoteConnection',
  },
  __typename: 'ComplianceManagement::Projects::ComplianceViolation',
};

export const mockComplianceViolationData = {
  data: {
    projectComplianceViolation: mockComplianceViolation,
  },
};

export const mockUpdateResponseData = {
  data: {
    updateProjectComplianceViolation: {
      clientMutationId: null,
      errors: [],
      complianceViolation: {
        status: 'RESOLVED',
        __typename: 'ComplianceManagement::Projects::ComplianceViolation',
      },
      __typename: 'UpdateProjectComplianceViolationPayload',
    },
  },
};

export const mockGraphQlError = jest.fn().mockRejectedValue(new Error('GraphQL error'));

export const mockDataWithoutAuditEvent = {
  data: {
    projectComplianceViolation: {
      ...mockComplianceViolation,
      auditEvent: null,
    },
  },
};

export const mockDataWithoutNotes = {
  data: {
    projectComplianceViolation: {
      ...mockComplianceViolation,
      notes: {
        nodes: [],
        __typename: 'NoteConnection',
      },
    },
  },
};

export const mockDataWithNullNotes = {
  data: {
    projectComplianceViolation: {
      ...mockComplianceViolation,
      notes: null,
    },
  },
};

export const mockDataWithOnlyNonSystemNotes = {
  data: {
    projectComplianceViolation: {
      ...mockComplianceViolation,
      notes: {
        nodes: [
          {
            id: 'gid://gitlab/Note/3',
            body: 'Regular comment',
            bodyHtml: '<p>Regular comment</p>',
            createdAt: '2025-06-16T12:00:00Z',
            lastEditedAt: null,
            lastEditedBy: null,
            author: {
              id: 'gid://gitlab/User/3',
              avatarUrl: 'https://example.com/avatar3.png',
              name: 'Test User 3',
              username: 'testuser3',
              webUrl: 'https://example.com/testuser3',
              webPath: '/testuser3',
              __typename: 'UserCore',
            },
            discussion: {
              id: 'gid://gitlab/Discussion/3',
              __typename: 'Discussion',
            },
            systemNoteIconName: null,
            system: false,
            internal: false,
            __typename: 'Note',
          },
          {
            id: 'gid://gitlab/Note/4',
            body: 'Another regular comment',
            bodyHtml: '<p>Another regular comment</p>',
            createdAt: '2025-06-16T13:00:00Z',
            lastEditedAt: null,
            lastEditedBy: null,
            author: {
              id: 'gid://gitlab/User/4',
              avatarUrl: 'https://example.com/avatar4.png',
              name: 'Test User 4',
              username: 'testuser4',
              webUrl: 'https://example.com/testuser4',
              webPath: '/testuser4',
              __typename: 'UserCore',
            },
            discussion: {
              id: 'gid://gitlab/Discussion/4',
              __typename: 'Discussion',
            },
            systemNoteIconName: null,
            system: false,
            internal: false,
            __typename: 'Note',
          },
        ],
        __typename: 'NoteConnection',
      },
    },
  },
};
