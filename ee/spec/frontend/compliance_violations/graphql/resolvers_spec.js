import { InMemoryCache } from '@apollo/client/core';
import { resolvers } from 'ee/compliance_violations/graphql/resolvers';
import complianceViolationQuery from 'ee/compliance_violations/graphql/compliance_violation.query.graphql';

describe('GraphQL resolvers', () => {
  let cache;

  beforeEach(() => {
    cache = new InMemoryCache();
  });

  const createMockComplianceViolation = (violationId, overrides = {}) => ({
    id: `gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/${violationId}`,
    status: 'IN_REVIEW',
    createdAt: '2025-06-16T02:20:41Z',
    complianceControl: {
      id: 'minimum_approvals_required_2',
      name: 'At least two approvals',
      complianceRequirement: {
        name: 'basic code regulation',
        framework: {
          id: 'gid://gitlab/ComplianceManagement::Framework/3',
          color: '#cd5b45',
          default: false,
          name: 'SOC 2',
          description: 'SOC 2 description',
        },
      },
    },
    project: {
      id: 'gid://gitlab/Project/2',
      nameWithNamespace: 'GitLab.org / GitLab Test',
      fullPath: 'gitlab-org/gitlab-test',
      webUrl: 'http://127.0.0.1:3000/gitlab-org/gitlab-test',
      __typename: 'Project',
    },
    auditEvent: {
      id: 'gid://gitlab/AuditEvents::ProjectAuditEvent/467',
      eventName: 'merge_request_merged',
      targetId: '2',
      details: '{}',
      ipAddress: '123.1.1.9',
      entityPath: 'gitlab-org/gitlab-test',
      entityId: '2',
      entityType: 'Project',
      author: {
        id: 'gid://gitlab/User/1',
        name: 'John Doe',
      },
      project: {
        id: 'gid://gitlab/Project/2',
        name: 'Test project',
        fullPath: 'gitlab-org/gitlab-test',
        webUrl: 'http://127.0.0.1:3000/gitlab-org/gitlab-test',
      },
      group: null,
      user: {
        id: 'gid://gitlab/User/1',
        name: 'John Doe',
      },
    },
    __typename: 'ComplianceViolation',
    ...overrides,
  });

  describe('Query resolvers', () => {
    describe('complianceViolation', () => {
      const violationId = 'gid://gitlab/ComplianceViolation/1';

      it('returns mock violation data when not in cache', () => {
        const result = resolvers.Query.complianceViolation(null, { id: violationId }, { cache });

        expect(result).toEqual(createMockComplianceViolation(violationId));
      });

      it('writes data to cache after first query', () => {
        resolvers.Query.complianceViolation(null, { id: violationId }, { cache });

        const cachedData = cache.readQuery({
          query: complianceViolationQuery,
          variables: { id: violationId },
        });

        expect(cachedData.complianceViolation).toEqual(createMockComplianceViolation(violationId));
      });

      it('returns cached data when available', () => {
        const cachedViolation = createMockComplianceViolation(violationId, { status: 'resolved' });

        cache.writeQuery({
          query: complianceViolationQuery,
          variables: { id: violationId },
          data: { complianceViolation: cachedViolation },
        });

        const result = resolvers.Query.complianceViolation(null, { id: violationId }, { cache });

        expect(result).toEqual(cachedViolation);
      });
    });
  });

  describe('Mutation resolvers', () => {
    describe('updateComplianceViolationStatus', () => {
      const violationId = 'gid://gitlab/ComplianceViolation/1';
      const input = { violationId, status: 'resolved' };

      beforeEach(() => {
        // Set up initial data in cache
        const initialData = {
          complianceViolation: createMockComplianceViolation(violationId),
        };

        cache.writeQuery({
          query: complianceViolationQuery,
          variables: { id: violationId },
          data: initialData,
        });
      });

      it('updates the status in cache and returns success payload', () => {
        const result = resolvers.Mutation.updateComplianceViolationStatus(
          null,
          { input },
          { cache },
        );

        expect(result).toMatchObject({
          clientMutationId: expect.any(String),
          errors: [],
          violation: {
            status: 'resolved',
            __typename: 'ComplianceViolation',
          },
          __typename: 'UpdateComplianceViolationStatusPayload',
        });

        // Verify cache was updated
        const updatedData = cache.readQuery({
          query: complianceViolationQuery,
          variables: { id: violationId },
        });

        expect(updatedData.complianceViolation.status).toBe('resolved');
      });

      it('returns error payload when cache read fails', () => {
        // Clear cache to simulate read failure
        cache.evict({ fieldName: 'complianceViolation' });

        const result = resolvers.Mutation.updateComplianceViolationStatus(
          null,
          { input },
          { cache },
        );

        expect(result).toMatchObject({
          clientMutationId: expect.any(String),
          errors: expect.arrayContaining([expect.any(String)]),
          violation: null,
          __typename: 'UpdateComplianceViolationStatusPayload',
        });
      });

      it('preserves other violation data when updating status', () => {
        resolvers.Mutation.updateComplianceViolationStatus(null, { input }, { cache });

        const updatedData = cache.readQuery({
          query: complianceViolationQuery,
          variables: { id: violationId },
        });

        expect(updatedData.complianceViolation).toMatchObject(
          createMockComplianceViolation(violationId, { status: 'resolved' }),
        );
      });
    });
  });
});
