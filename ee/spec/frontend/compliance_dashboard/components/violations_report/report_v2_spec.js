import { GlAlert, GlLoadingIcon, GlTable, GlKeysetPagination } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import ComplianceViolationsReportV2, {
  VIOLATION_PAGE_SIZE,
} from 'ee/compliance_dashboard/components/violations_report/report_v2.vue';
import { ComplianceViolationStatusDropdown } from 'ee/vue_shared/compliance';
import groupComplianceViolationsQuery from 'ee/compliance_violations/graphql/compliance_violations.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

Vue.use(VueApollo);

jest.mock('~/graphql_shared/utils', () => ({
  getIdFromGraphQLId: jest.fn(),
}));

describe('ComplianceViolationsReportV2 component', () => {
  let wrapper;

  const groupPath = 'group-path';

  const mockViolationsResponse = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        name: 'Test Group',
        projectComplianceViolations: {
          nodes: [
            {
              id: 'gid://gitlab/ComplianceViolation/1',
              createdAt: '2025-06-08T10:00:00Z',
              status: 'detected',
              linkedAuditEventId: 'audit_event_1',
              project: {
                id: 'gid://gitlab/Project/1',
                name: 'Frontend Project',
                fullPath: 'foo/bar',
              },
              complianceControl: {
                id: 'gid://gitlab/ComplianceControl/1',
                name: 'SOX - Code Review Required',
              },
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: 'cursor1',
            endCursor: 'cursor1',
          },
        },
      },
    },
  };

  const mockViolationsResponseWithPagination = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        name: 'Test Group',
        projectComplianceViolations: {
          nodes: [
            {
              id: 'gid://gitlab/ComplianceViolation/1',
              createdAt: '2025-06-08T10:00:00Z',
              status: 'detected',
              linkedAuditEventId: 'audit_event_1',
              project: {
                id: 'gid://gitlab/Project/1',
                name: 'Frontend Project',
                fullPath: 'foo/bar',
              },
              complianceControl: {
                id: 'gid://gitlab/ComplianceControl/1',
                name: 'SOX - Code Review Required',
              },
            },
            {
              id: 'gid://gitlab/ComplianceViolation/2',
              createdAt: '2025-06-09T10:00:00Z',
              status: 'resolved',
              linkedAuditEventId: 'audit_event_2',
              project: {
                id: 'gid://gitlab/Project/2',
                name: 'Backend Project',
                fullPath: 'foo/baz',
              },
              complianceControl: {
                id: 'gid://gitlab/ComplianceControl/2',
                name: 'SOX - Approval Required',
              },
            },
          ],
          pageInfo: {
            hasNextPage: true,
            hasPreviousPage: false,
            startCursor: 'cursor1',
            endCursor: 'cursor2',
          },
        },
      },
    },
  };

  const mockGraphQlSuccess = jest.fn().mockResolvedValue(mockViolationsResponse);
  const mockGraphQlLoading = jest.fn().mockResolvedValue(new Promise(() => {}));
  const mockGraphQlError = jest.fn().mockRejectedValue(new Error('GraphQL error'));

  const findErrorMessage = () => wrapper.findComponent(GlAlert);
  const findViolationsTable = () => wrapper.findComponent(GlTable);
  const findTableLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findStatusDropdown = () => wrapper.findComponent(ComplianceViolationStatusDropdown);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  const createMockApolloProvider = (resolverMock = mockGraphQlLoading) => {
    return createMockApollo([[groupComplianceViolationsQuery, resolverMock]]);
  };

  const createComponent = (
    mountFn = shallowMount,
    props = {},
    resolverMock = mockGraphQlLoading,
  ) => {
    return extendedWrapper(
      mountFn(ComplianceViolationsReportV2, {
        apolloProvider: createMockApolloProvider(resolverMock),
        propsData: {
          groupPath,
          ...props,
        },
        stubs: {
          GlTable: false,
        },
      }),
    );
  };

  describe('default behavior', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('does not render an error message', () => {
      expect(findErrorMessage().exists()).toBe(false);
    });

    it('renders the violations table', () => {
      expect(findViolationsTable().exists()).toBe(true);
    });
  });

  describe('when initializing', () => {
    beforeEach(() => {
      wrapper = createComponent(mount, {}, mockGraphQlLoading);
    });

    it('renders the table loading icon', () => {
      expect(findViolationsTable().exists()).toBe(true);
      expect(findTableLoadingIcon().exists()).toBe(true);
    });

    it('fetches the list of compliance violations', () => {
      expect(mockGraphQlLoading).toHaveBeenCalledTimes(1);
      expect(mockGraphQlLoading).toHaveBeenCalledWith({
        fullPath: groupPath,
        first: VIOLATION_PAGE_SIZE,
        after: null,
        before: null,
      });
    });
  });

  describe('when the query fails', () => {
    beforeEach(async () => {
      wrapper = createComponent(shallowMount, {}, mockGraphQlError);
      await waitForPromises();
    });

    it('renders the error message', () => {
      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessage().text()).toBe(
        'Unable to load the compliance violations report. Refresh the page and try again.',
      );
    });
  });

  describe('when there are violations', () => {
    beforeEach(async () => {
      wrapper = createComponent(mount, {}, mockGraphQlSuccess);
      await waitForPromises();
    });

    it('does not render the table loading icon', () => {
      expect(findTableLoadingIcon().exists()).toBe(false);
    });

    it('renders violation data correctly', () => {
      const tableRows = wrapper.findAll('tbody tr');
      expect(tableRows).toHaveLength(1);

      const firstRow = tableRows.at(0);
      expect(firstRow.text()).toContain('Frontend Project');
      expect(firstRow.text()).toContain('Code Review Required');
    });

    it('renders status dropdown', () => {
      const statusDropdown = findStatusDropdown();

      expect(statusDropdown.exists()).toBe(true);
      expect(statusDropdown.props('disabled')).toBe(false);
      expect(statusDropdown.props('value')).toBe('detected');
      expect(statusDropdown.vm.selectedOption.text).toBe('Detected');
    });
  });

  describe('when there are no violations', () => {
    beforeEach(async () => {
      const emptyResponse = {
        data: {
          group: {
            id: 'gid://gitlab/Group/1',
            name: 'Test Group',
            projectComplianceViolations: {
              nodes: [],
              pageInfo: {
                hasNextPage: false,
                hasPreviousPage: false,
                startCursor: null,
                endCursor: null,
              },
            },
          },
        },
      };
      const mockResolver = jest.fn().mockResolvedValue(emptyResponse);
      wrapper = createComponent(mount, {}, mockResolver);
      await waitForPromises();
    });

    it('renders the empty table message', () => {
      expect(findViolationsTable().text()).toContain('No violations found');
    });
  });

  describe('pagination', () => {
    const paginationTestCases = {
      initial: {
        hasNextPage: true,
        hasPreviousPage: false,
        startCursor: 'cursor1',
        endCursor: 'cursor2',
      },
      afterNext: {
        expectedCursor: { after: 'cursor2', before: null },
      },
      afterPrevious: {
        expectedCursor: { before: 'cursor1', after: null },
      },
    };

    const expectPaginationProps = (expectedProps) => {
      const pagination = findPagination();
      Object.entries(expectedProps).forEach(([prop, value]) => {
        expect(pagination.props(prop)).toBe(value);
      });
    };

    const expectCursorState = (expectedCursor) => {
      Object.entries(expectedCursor).forEach(([key, value]) => {
        expect(wrapper.vm.cursor[key]).toBe(value);
      });
    };

    const triggerPaginationEvent = async (event) => {
      const pagination = findPagination();
      pagination.vm.$emit(event);
      await nextTick();
    };

    beforeEach(async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponseWithPagination);
      wrapper = createComponent(mount, {}, mockResolver);
      await waitForPromises();
    });

    it('renders pagination component with correct initial state', () => {
      expect(findPagination().exists()).toBe(true);
      expectPaginationProps(paginationTestCases.initial);
    });

    describe('navigation', () => {
      it('handles next page navigation correctly', async () => {
        await triggerPaginationEvent('next');
        expectCursorState(paginationTestCases.afterNext.expectedCursor);
      });

      it('handles previous page navigation correctly', async () => {
        await triggerPaginationEvent('prev');
        expectCursorState(paginationTestCases.afterPrevious.expectedCursor);
      });
    });
  });

  describe('getViolationDetailsPath', () => {
    beforeEach(() => {
      wrapper = createComponent();
      // Reset mock and set default behavior
      getIdFromGraphQLId.mockReset();
      getIdFromGraphQLId.mockImplementation((id) => {
        const match = id.match(/\/(\d+)$/);
        return match ? match[1] : null;
      });
    });

    it('returns correct path for valid violation with fullPath', () => {
      const violation = {
        id: 'gid://gitlab/ComplianceViolation/123',
        project: {
          fullPath: 'group/project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('/group/project/-/security/compliance_violations/123');
    });

    it('returns correct path for valid violation with path_with_namespace', () => {
      const violation = {
        id: 'gid://gitlab/ComplianceViolation/456',
        project: {
          path_with_namespace: 'group/another-project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('/group/another-project/-/security/compliance_violations/456');
    });

    it('prefers fullPath over path_with_namespace when both exist', () => {
      const violation = {
        id: 'gid://gitlab/ComplianceViolation/789',
        project: {
          fullPath: 'group/preferred-project',
          path_with_namespace: 'group/fallback-project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('/group/preferred-project/-/security/compliance_violations/789');
    });

    it('returns # when violation is null or undefined', () => {
      expect(wrapper.vm.getViolationDetailsPath(null)).toBe('#');
      expect(wrapper.vm.getViolationDetailsPath(undefined)).toBe('#');
    });

    it('returns # when violation.id is missing', () => {
      const violation = {
        project: {
          fullPath: 'group/project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('#');
    });

    it('returns # when violation.project is missing', () => {
      const violation = {
        id: 'gid://gitlab/ComplianceViolation/123',
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('#');
    });

    it('returns # when both fullPath and path_with_namespace are missing', () => {
      const violation = {
        id: 'gid://gitlab/ComplianceViolation/123',
        project: {},
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('#');
    });

    it('returns # when getIdFromGraphQLId throws an error', () => {
      getIdFromGraphQLId.mockImplementation(() => {
        throw new Error('Invalid GraphQL ID');
      });

      const violation = {
        id: 'invalid-graphql-id',
        project: {
          fullPath: 'group/project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('#');
    });

    it('returns # when getIdFromGraphQLId returns null or empty', () => {
      getIdFromGraphQLId.mockReturnValue(null);

      const violation = {
        id: 'gid://gitlab/ComplianceViolation/123',
        project: {
          fullPath: 'group/project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('#');
    });
  });
});
