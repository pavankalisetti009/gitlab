import groupComplianceRequirementsStatusesQuery from '../graphql/queries/group_compliance_requirements_statuses.query.graphql';

const DEFAULT_PAGESIZE = 20;

const defaultPageInfo = () => ({
  startCursor: null,
  endCursor: null,
  hasNextPage: false,
  hasPreviousPage: false,
});

export class GroupedLoader {
  constructor(options = {}) {
    this.groupBy = options.groupBy || null;
    this.apollo = options.apollo;
    this.pageSize = options.pageSize || DEFAULT_PAGESIZE;

    this.fullPath = options.fullPath;
    this.filters = {};

    if (!this.apollo || !this.fullPath) {
      throw new Error('Missing apollo client or fullPath');
    }
  }

  async loadPage(options = {}) {
    const result = await this.apollo.query({
      query: groupComplianceRequirementsStatusesQuery,
      variables: {
        fullPath: this.fullPath,
        filters: this.filters,
        [options.before ? 'last' : 'first']: this.pageSize,
        ...options,
      },
    });

    const statuses = result.data.group.projectComplianceRequirementsStatus;
    this.pageInfo = statuses.pageInfo;

    return {
      data: [
        {
          group: null,
          children: statuses.nodes,
        },
      ],
      pageInfo: this.pageInfo,
    };
  }

  resetPagination() {
    this.pageInfo = defaultPageInfo();
  }

  setPageSize(newPageSize) {
    this.pageSize = newPageSize;
    this.resetPagination();
  }

  loadNextPage() {
    return this.loadPage({
      after: this.pageInfo.endCursor,
    });
  }

  loadPrevPage() {
    return this.loadPage({
      before: this.pageInfo.startCursor,
    });
  }

  setFilters(newFilters) {
    this.filters = newFilters;
    this.resetPagination();
  }
}
