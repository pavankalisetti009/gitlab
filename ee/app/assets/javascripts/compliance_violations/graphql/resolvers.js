/* eslint-disable @gitlab/require-i18n-strings */
import produce from 'immer';
import { uniqueId } from 'lodash';
import complianceViolationQuery from './compliance_violation.query.graphql';

const getMockViolationData = (id) => ({
  id: `gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/${id}`,
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
