import {
  formatListboxItems,
  getReplicableTypeFilter,
  getReplicationStatusFilter,
  getVerificationStatusFilter,
  processFilters,
  formatGraphqlIds,
  getGraphqlFilterVariables,
  getAvailableFilteredSearchTokens,
  getPaginationObject,
} from 'ee/geo_replicable/filters';
import {
  TOKEN_TYPES,
  FILTERED_SEARCH_TOKENS,
  DEFAULT_PAGE_SIZE,
} from 'ee/geo_replicable/constants';
import { TEST_HOST } from 'spec/test_constants';
import { MOCK_REPLICABLE_TYPES, MOCK_GRAPHQL_REGISTRY_CLASS } from './mock_data';

describe('GeoReplicable filters', () => {
  describe('formatListboxItems', () => {
    it('returns the data property formatted', () => {
      expect(formatListboxItems(MOCK_REPLICABLE_TYPES)).toStrictEqual(
        MOCK_REPLICABLE_TYPES.map((r) => ({ text: r.titlePlural, value: r.namePlural })),
      );
    });
  });

  describe('getReplicableTypeFilter', () => {
    it('returns the data property formatted', () => {
      expect(getReplicableTypeFilter('mock_type')).toStrictEqual({
        type: TOKEN_TYPES.REPLICABLE_TYPE,
        value: 'mock_type',
      });
    });
  });

  describe('getReplicationStatusFilter', () => {
    it('returns the data property formatted', () => {
      expect(getReplicationStatusFilter('synced')).toStrictEqual({
        type: TOKEN_TYPES.REPLICATION_STATUS,
        value: {
          data: 'synced',
        },
      });
    });
  });

  describe('getVerificationStatusFilter', () => {
    it('returns the data property formatted', () => {
      expect(getVerificationStatusFilter('succeeded')).toStrictEqual({
        type: TOKEN_TYPES.VERIFICATION_STATUS,
        value: {
          data: 'succeeded',
        },
      });
    });
  });

  describe('processFilters', () => {
    const originalLocationHref = window.location.href;

    beforeEach(() => {
      Object.defineProperty(window, 'location', {
        writable: true,
        value: { href: `${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type` },
      });
    });

    afterEach(() => {
      Object.defineProperty(window, 'location', {
        writable: true,
        value: { href: originalLocationHref },
      });
    });

    it.each`
      filters                                                                                                                                                       | expected
      ${[]}                                                                                                                                                         | ${{ query: {}, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[getReplicableTypeFilter('mock_type')]}                                                                                                                     | ${{ query: {}, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/mock_type`) }}
      ${[getReplicationStatusFilter('synced')]}                                                                                                                     | ${{ query: { replication_status: 'synced' }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[getVerificationStatusFilter('succeeded')]}                                                                                                                 | ${{ query: { verification_status: 'succeeded' }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[`${MOCK_GRAPHQL_REGISTRY_CLASS}/1`]}                                                                                                                       | ${{ query: { ids: `${MOCK_GRAPHQL_REGISTRY_CLASS}/1` }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[`${MOCK_GRAPHQL_REGISTRY_CLASS}/1 ${MOCK_GRAPHQL_REGISTRY_CLASS}/2`]}                                                                                      | ${{ query: { ids: `${MOCK_GRAPHQL_REGISTRY_CLASS}/1 ${MOCK_GRAPHQL_REGISTRY_CLASS}/2` }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[getReplicableTypeFilter('mock_type'), getReplicationStatusFilter('synced'), getVerificationStatusFilter('succeeded'), `${MOCK_GRAPHQL_REGISTRY_CLASS}/1`]} | ${{ query: { replication_status: 'synced', verification_status: 'succeeded', ids: `${MOCK_GRAPHQL_REGISTRY_CLASS}/1` }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/mock_type`) }}
    `('returns the correct { query, url }', ({ filters, expected }) => {
      expect(processFilters(filters)).toStrictEqual(expected);
    });
  });

  describe('formatGraphqlIds', () => {
    it.each`
      description                             | ids                                                                                                  | expected
      ${'no ids provided'}                    | ${null}                                                                                              | ${null}
      ${'empty string provided'}              | ${''}                                                                                                | ${null}
      ${'single numeric ID'}                  | ${'123'}                                                                                             | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`]}
      ${'multiple numeric IDs'}               | ${'123 456 789'}                                                                                     | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/789`]}
      ${'single GraphQL ID'}                  | ${`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`}                                                 | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`]}
      ${'multiple GraphQL IDs'}               | ${`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123 gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`} | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`]}
      ${'mixed numeric and GraphQL IDs'}      | ${`123 gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`}                                             | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`]}
      ${'registry class format ID'}           | ${`${MOCK_GRAPHQL_REGISTRY_CLASS}/123`}                                                              | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`]}
      ${'multiple registry class format IDs'} | ${`${MOCK_GRAPHQL_REGISTRY_CLASS}/123 ${MOCK_GRAPHQL_REGISTRY_CLASS}/456`}                           | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`]}
      ${'mixed formats'}                      | ${`123 ${MOCK_GRAPHQL_REGISTRY_CLASS}/456 gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/789`}          | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/789`]}
    `('returns $expected when $description', ({ ids, expected }) => {
      expect(
        formatGraphqlIds({ ids, graphqlRegistryClass: MOCK_GRAPHQL_REGISTRY_CLASS }),
      ).toStrictEqual(expected);
    });
  });

  describe('getGraphqlFilterVariables', () => {
    it.each`
      description                                | filters                                                                                                                                                       | expected
      ${'no filters provided'}                   | ${[]}                                                                                                                                                         | ${{ replicationState: null, verificationState: null, ids: null }}
      ${'no replication status filter provided'} | ${[getReplicableTypeFilter('mock_type')]}                                                                                                                     | ${{ replicationState: null, verificationState: null, ids: null }}
      ${'replication status filter provided'}    | ${[getReplicationStatusFilter('synced')]}                                                                                                                     | ${{ replicationState: 'SYNCED', verificationState: null, ids: null }}
      ${'verification status filter provided'}   | ${[getVerificationStatusFilter('succeeded')]}                                                                                                                 | ${{ replicationState: null, verificationState: 'SUCCEEDED', ids: null }}
      ${'ids filter provided'}                   | ${[`${MOCK_GRAPHQL_REGISTRY_CLASS}/1`]}                                                                                                                       | ${{ replicationState: null, verificationState: null, ids: [`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/1`] }}
      ${'multiple ids filter provided'}          | ${[`${MOCK_GRAPHQL_REGISTRY_CLASS}/1 ${MOCK_GRAPHQL_REGISTRY_CLASS}/2`]}                                                                                      | ${{ replicationState: null, verificationState: null, ids: [`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/1`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/2`] }}
      ${'multiple filters provided'}             | ${[getReplicableTypeFilter('mock_type'), getReplicationStatusFilter('failed'), getVerificationStatusFilter('succeeded'), `${MOCK_GRAPHQL_REGISTRY_CLASS}/1`]} | ${{ replicationState: 'FAILED', verificationState: 'SUCCEEDED', ids: [`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/1`] }}
    `('returns correct variables when $description', ({ filters, expected }) => {
      expect(
        getGraphqlFilterVariables({ filters, graphqlRegistryClass: MOCK_GRAPHQL_REGISTRY_CLASS }),
      ).toStrictEqual(expected);
    });
  });

  describe('getAvailableFilteredSearchTokens', () => {
    it.each`
      description                   | verificationEnabled | expected
      ${'verification is disabled'} | ${false}            | ${FILTERED_SEARCH_TOKENS.filter((filter) => filter.type !== TOKEN_TYPES.VERIFICATION_STATUS)}
      ${'verification is enabled'}  | ${true}             | ${FILTERED_SEARCH_TOKENS}
    `('returns correct tokens when $description', ({ verificationEnabled, expected }) => {
      expect(getAvailableFilteredSearchTokens(verificationEnabled)).toStrictEqual(expected);
    });
  });

  describe('getPaginationObject', () => {
    it.each`
      description                                         | cursor                                            | expected
      ${'no parameters provided'}                         | ${{}}                                             | ${{ before: '', after: '', first: DEFAULT_PAGE_SIZE, last: null }}
      ${'empty parameters provided'}                      | ${{ before: '', after: '', first: '', last: '' }} | ${{ before: '', after: '', first: DEFAULT_PAGE_SIZE, last: null }}
      ${'first parameter is provided as String'}          | ${{ first: '10' }}                                | ${{ before: '', after: '', first: 10, last: null }}
      ${'first parameter is provided as Number'}          | ${{ first: 10 }}                                  | ${{ before: '', after: '', first: 10, last: null }}
      ${'first parameter is provided as negative Number'} | ${{ first: -10 }}                                 | ${{ before: '', after: '', first: DEFAULT_PAGE_SIZE, last: null }}
      ${'last parameter is provided as String'}           | ${{ last: '10' }}                                 | ${{ before: '', after: '', first: null, last: 10 }}
      ${'last parameter is provided as Number'}           | ${{ last: 10 }}                                   | ${{ before: '', after: '', first: null, last: 10 }}
      ${'last parameter is provided as negative Number'}  | ${{ last: -10 }}                                  | ${{ before: '', after: '', first: DEFAULT_PAGE_SIZE, last: null }}
      ${'next page pagination object is provided'}        | ${{ after: 'cursor123', first: 10 }}              | ${{ before: '', after: 'cursor123', first: 10, last: null }}
      ${'prev page pagination object is provided'}        | ${{ before: 'cursor123', last: 10 }}              | ${{ before: 'cursor123', after: '', first: null, last: 10 }}
    `('returns correct pagination object when $description', ({ cursor, expected }) => {
      expect(getPaginationObject(cursor)).toStrictEqual(expected);
    });
  });
});
