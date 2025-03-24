import { getReplicableTypeFilter } from 'ee/geo_replicable/filters';
import { TOKEN_TYPES } from 'ee/geo_replicable/constants';

describe('GeoReplicable filters', () => {
  describe('getReplicableTypeFilter', () => {
    it('returns the data property formatted', () => {
      expect(getReplicableTypeFilter('mock_type')).toStrictEqual({
        type: TOKEN_TYPES.REPLICABLE_TYPE,
        value: 'mock_type',
      });
    });
  });
});
