import { InMemoryCache } from '@apollo/client/core';
import { resolvers } from 'ee/compliance_violations/graphql/resolvers';
import complianceViolationQuery from 'ee/compliance_violations/graphql/compliance_violation.query.graphql';

describe('GraphQL resolvers', () => {
  let cache;

  beforeEach(() => {
    cache = new InMemoryCache();
  });

  describe('Query resolvers', () => {
    describe('complianceViolation', () => {
      const violationId = 'gid://gitlab/ComplianceViolation/1';

      it('returns mock violation data when not in cache', () => {
        const result = resolvers.Query.complianceViolation(null, { id: violationId }, { cache });

        expect(result).toEqual({
          id: violationId,
          status: 'in_review',
          project: {
            id: 2,
            nameWithNamespace: 'GitLab.org / GitLab Test',
            fullPath: '/gitlab/org/gitlab-test',
            webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
            __typename: 'Project',
          },
          __typename: 'ComplianceViolation',
        });
      });

      it('writes data to cache after first query', () => {
        resolvers.Query.complianceViolation(null, { id: violationId }, { cache });

        const cachedData = cache.readQuery({
          query: complianceViolationQuery,
          variables: { id: violationId },
        });

        expect(cachedData.complianceViolation).toEqual({
          id: violationId,
          status: 'in_review',
          project: {
            id: 2,
            nameWithNamespace: 'GitLab.org / GitLab Test',
            fullPath: '/gitlab/org/gitlab-test',
            webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
            __typename: 'Project',
          },
          __typename: 'ComplianceViolation',
        });
      });

      it('returns cached data when available', () => {
        const cachedViolation = {
          id: violationId,
          status: 'resolved',
          project: {
            id: 3,
            nameWithNamespace: 'Cached Project',
            fullPath: '/cached/project',
            webUrl: 'https://localhost:3000/cached/project',
            __typename: 'Project',
          },
          __typename: 'ComplianceViolation',
        };

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
          complianceViolation: {
            id: violationId,
            status: 'in_review',
            project: {
              id: 2,
              nameWithNamespace: 'GitLab.org / GitLab Test',
              fullPath: '/gitlab/org/gitlab-test',
              webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
              __typename: 'Project',
            },
            __typename: 'ComplianceViolation',
          },
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

        expect(updatedData.complianceViolation).toMatchObject({
          id: violationId,
          status: 'resolved', // Updated
          project: {
            id: 2,
            nameWithNamespace: 'GitLab.org / GitLab Test',
            fullPath: '/gitlab/org/gitlab-test',
            webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
            __typename: 'Project',
          },
          __typename: 'ComplianceViolation',
        });
      });
    });
  });
});
