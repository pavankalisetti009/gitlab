import { getReplicableTypeFilter, processFilters } from 'ee/geo_replicable/filters';
import { TOKEN_TYPES } from 'ee/geo_replicable/constants';
import { TEST_HOST } from 'spec/test_constants';

describe('GeoReplicable filters', () => {
  describe('getReplicableTypeFilter', () => {
    it('returns the data property formatted', () => {
      expect(getReplicableTypeFilter('mock_type')).toStrictEqual({
        type: TOKEN_TYPES.REPLICABLE_TYPE,
        value: 'mock_type',
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
      filters                                   | expected
      ${[]}                                     | ${{ query: {}, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[getReplicableTypeFilter('mock_type')]} | ${{ query: {}, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/mock_type`) }}
    `('returns the correct { query, url }', ({ filters, expected }) => {
      expect(processFilters(filters)).toStrictEqual(expected);
    });
  });
});
