import {
  formatListboxItems,
  getReplicableTypeFilter,
  getReplicationStatusFilter,
  processFilters,
  getGraphqlFilterVariables,
} from 'ee/geo_replicable/filters';
import { TOKEN_TYPES } from 'ee/geo_replicable/constants';
import { TEST_HOST } from 'spec/test_constants';
import { MOCK_REPLICABLE_TYPES } from './mock_data';

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
      filters                                                                         | expected
      ${[]}                                                                           | ${{ query: {}, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[getReplicableTypeFilter('mock_type')]}                                       | ${{ query: {}, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/mock_type`) }}
      ${[getReplicationStatusFilter('synced')]}                                       | ${{ query: { replication_status: 'synced' }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[getReplicableTypeFilter('mock_type'), getReplicationStatusFilter('synced')]} | ${{ query: { replication_status: 'synced' }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/mock_type`) }}
    `('returns the correct { query, url }', ({ filters, expected }) => {
      expect(processFilters(filters)).toStrictEqual(expected);
    });
  });

  describe('getGraphqlFilterVariables', () => {
    it.each`
      description                                | filters                                                                         | expected
      ${'no filters provided'}                   | ${[]}                                                                           | ${{ replicationState: null }}
      ${'no replication status filter provided'} | ${[getReplicableTypeFilter('mock_type')]}                                       | ${{ replicationState: null }}
      ${'replication status filter provided'}    | ${[getReplicationStatusFilter('synced')]}                                       | ${{ replicationState: 'SYNCED' }}
      ${'multiple filters provided'}             | ${[getReplicableTypeFilter('mock_type'), getReplicationStatusFilter('failed')]} | ${{ replicationState: 'FAILED' }}
    `('returns correct variables when $description', ({ filters, expected }) => {
      expect(getGraphqlFilterVariables(filters)).toStrictEqual(expected);
    });
  });
});
