import { FILTER, REPORT_STATUS } from './constants';

export default () => ({
  endpoint: '',
  exportEndpoint: '',
  vulnerabilityInfo: {},
  vulnerabilityItemsLoading: [],
  fetchingInProgress: false,
  initialized: false,
  isLoading: false,
  errorLoading: false,
  dependencies: [],
  namespaceType: '',
  pageInfo: {
    total: 0,
  },
  reportInfo: {
    status: REPORT_STATUS.ok,
  },
  filter: FILTER.all,
  searchFilterParameters: {},
  sortField: null,
  sortOrder: null,
  licenses: [],
  fetchingLicensesInProgress: false,
});
