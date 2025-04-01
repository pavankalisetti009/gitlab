import { GroupedLoader } from 'ee/compliance_dashboard/components/standards_adherence_report/services/grouped_loader';
import groupComplianceRequirementsStatusesQuery from 'ee/compliance_dashboard/components/standards_adherence_report/graphql/queries/group_compliance_requirements_statuses.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createMockGroupComplianceRequirementsStatusesData } from './mock_data';

describe('GroupedLoader', () => {
  let mockApollo;
  let mockQueryResponse;
  let mockGroupRequirementsStatusQuery;

  const fullPath = 'example-group';
  const DEFAULT_PAGESIZE = 20;

  beforeEach(() => {
    mockQueryResponse = createMockGroupComplianceRequirementsStatusesData();
    mockGroupRequirementsStatusQuery = jest.fn().mockResolvedValue(mockQueryResponse);
    mockApollo = createMockApollo([
      [groupComplianceRequirementsStatusesQuery, mockGroupRequirementsStatusQuery],
    ]);
  });

  describe('loadPage', () => {
    let loader;

    beforeEach(() => {
      loader = new GroupedLoader({ apollo: mockApollo.defaultClient, fullPath });
    });

    it('calls the Apollo query with the correct parameters for first page', async () => {
      await loader.loadPage();

      expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        first: DEFAULT_PAGESIZE,
      });
    });

    it('calls the Apollo query with the correct parameters when "after" cursor is provided', async () => {
      const after = 'next-cursor';
      await loader.loadPage({ after });

      expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        first: DEFAULT_PAGESIZE,
        after,
      });
    });

    it('calls the Apollo query with the correct parameters when "before" cursor is provided', async () => {
      const before = 'prev-cursor';
      await loader.loadPage({ before });

      expect(mockGroupRequirementsStatusQuery).toHaveBeenCalledWith({
        fullPath,
        last: DEFAULT_PAGESIZE,
        before,
      });
    });

    it('returns properly structured data and pageInfo for non-grouped query', async () => {
      const result = await loader.loadPage();

      expect(result).toEqual({
        data: [
          {
            group: null,
            children: mockQueryResponse.data.group.projectComplianceRequirementsStatus.nodes,
          },
        ],
        pageInfo: mockQueryResponse.data.group.projectComplianceRequirementsStatus.pageInfo,
      });
    });

    it('stores pageInfo internally', async () => {
      await loader.loadPage();

      expect(loader.pageInfo).toEqual(
        mockQueryResponse.data.group.projectComplianceRequirementsStatus.pageInfo,
      );
    });
  });
});
