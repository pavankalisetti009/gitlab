import produce from 'immer';
import { uniqueId } from 'lodash';
import complianceViolationQuery from './compliance_violation.query.graphql';

const getMockViolationData = (id) => ({
  id,
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

export const resolvers = {
  Query: {
    complianceViolation: (_, { id }, { cache }) => {
      // First, try to read from cache
      try {
        const cachedData = cache.readQuery({
          query: complianceViolationQuery,
          variables: { id },
        });
        if (cachedData?.complianceViolation) {
          return cachedData.complianceViolation;
        }
      } catch (error) {
        // Cache miss is expected on first load
      }

      // If not in cache, get the data
      const violationData = getMockViolationData(id);

      // Write to cache for future queries
      cache.writeQuery({
        query: complianceViolationQuery,
        variables: { id },
        data: {
          complianceViolation: violationData,
        },
      });

      return violationData;
    },
  },
  Mutation: {
    updateComplianceViolationStatus: (_, { input }, { cache }) => {
      const { violationId, status } = input;

      try {
        const sourceData = cache.readQuery({
          query: complianceViolationQuery,
          variables: { id: violationId },
        });

        const updatedData = produce(sourceData, (draftData) => {
          if (draftData.complianceViolation) {
            draftData.complianceViolation.status = status;
          }
        });

        cache.writeQuery({
          query: complianceViolationQuery,
          variables: { id: violationId },
          data: updatedData,
        });

        return {
          clientMutationId: uniqueId(),
          errors: [],
          violation: {
            status,
            __typename: 'ComplianceViolation',
          },
          __typename: 'UpdateComplianceViolationStatusPayload',
        };
      } catch (error) {
        return {
          clientMutationId: uniqueId(),
          errors: [error.message],
          violation: null,
          __typename: 'UpdateComplianceViolationStatusPayload',
        };
      }
    },
  },
};
