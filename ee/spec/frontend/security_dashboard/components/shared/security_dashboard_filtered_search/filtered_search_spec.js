import { nextTick } from 'vue';
import { GlFilteredSearch } from '@gitlab/ui';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filters/constants';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';

const TEST_TOKEN_A_DEFINITION = {
  type: 'tokenA',
  title: 'Token A',
  multiSelect: true,
  unique: true,
  token: markRaw(() => {}),
  operators: OPERATORS_OR,
};

const TEST_TOKEN_B_DEFINITION = {
  ...TEST_TOKEN_A_DEFINITION,
  type: 'tokenB',
  title: 'Token B',
};

describe('Security Dashboard Filtered Search', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(FilteredSearch, {
      propsData: {
        tokens: [TEST_TOKEN_A_DEFINITION, TEST_TOKEN_B_DEFINITION],
        ...props,
      },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  const updateToken = async (type, data) => {
    const input = [{ type, value: { data } }];

    findFilteredSearch().vm.$emit('input', input);
    findFilteredSearch().vm.$emit('token-complete', { type });
    await nextTick();
  };

  const destroyToken = async (type) => {
    findFilteredSearch().vm.$emit('token-destroy', { type });
    await nextTick();
  };

  const clearFilters = async () => {
    findFilteredSearch().vm.$emit('clear');
    await nextTick();
  };

  const expectUrlToBe = (expectedUrl) => {
    expect(window.history.pushState).toHaveBeenCalledWith({}, '', expectedUrl);
  };

  const getLastEmittedFilters = () => {
    return wrapper.emitted('filters-changed').at(-1)[0];
  };

  beforeEach(() => {
    jest.spyOn(window.history, 'pushState');
  });

  afterEach(() => {
    setWindowLocation('');
  });

  it('renders GlFilteredSearch with correct props', () => {
    createWrapper();

    const filteredSearch = findFilteredSearch();

    expect(filteredSearch.props()).toMatchObject({
      placeholder: 'Filter results...',
      availableTokens: [TEST_TOKEN_A_DEFINITION, TEST_TOKEN_B_DEFINITION],
      value: [],
    });
  });

  describe('filters-changed event', () => {
    beforeEach(createWrapper);

    it('emits filters-changed when token is completed', async () => {
      await updateToken('tokenA', ['5', '10']);

      expect(wrapper.emitted('filters-changed')).toEqual([[{ tokenA: ['5', '10'] }]]);
    });

    it('maintains other filters when adding a new token', async () => {
      await updateToken('tokenA', ['5']);
      await updateToken('tokenB', ['15']);

      expect(getLastEmittedFilters()).toEqual({
        tokenA: ['5'],
        tokenB: ['15'],
      });
    });

    it('updates existing filter when token is modified', async () => {
      await updateToken('tokenA', ['5', '10']);
      await updateToken('tokenA', ['20']);

      expect(wrapper.emitted('filters-changed')).toHaveLength(2);
      expect(getLastEmittedFilters()).toEqual({ tokenA: ['20'] });
    });

    it('removes only the destroyed token while maintaining others', async () => {
      await updateToken('tokenA', ['5']);
      await updateToken('tokenB', ['15']);
      await destroyToken('tokenA');

      expect(getLastEmittedFilters()).toEqual({ tokenB: ['15'] });
    });

    it('emits empty filters when last token is destroyed', async () => {
      await updateToken('tokenA', ['5', '10']);
      await destroyToken('tokenA');

      expect(getLastEmittedFilters()).toEqual({});
    });

    it('removes ALL_ID value from token value', async () => {
      await updateToken('tokenA', [ALL_ID]);

      expect(wrapper.emitted('filters-changed')).toEqual([[{ tokenA: [] }]]);
    });

    it('emits empty filters on clear', async () => {
      await updateToken('tokenA', ['5', '10']);
      await updateToken('tokenB', ['15']);
      await clearFilters();

      expect(getLastEmittedFilters()).toEqual({});
    });

    it('does not emit duplicate filters-changed events for same filter values', async () => {
      await updateToken('tokenA', ['5', '10']);

      // Try to update with same values
      await updateToken('tokenA', ['5', '10']);

      expect(wrapper.emitted('filters-changed')).toHaveLength(1);
    });
  });

  describe('sync from url parameters on component create', () => {
    it('initializes filters from URL parameters on mount', () => {
      setWindowLocation('?tokenA=5,10&tokenB=20');
      createWrapper();

      expect(wrapper.emitted('filters-changed')).toHaveLength(1);
      expect(getLastEmittedFilters()).toEqual({
        tokenA: ['5', '10'],
        tokenB: ['20'],
      });
    });

    it('sets filtered search value from URL parameters', () => {
      setWindowLocation('?tokenA=5,10');
      createWrapper();

      expect(findFilteredSearch().props('value')).toEqual([
        {
          type: 'tokenA',
          value: {
            data: ['5', '10'],
            operator: '||',
          },
        },
      ]);
    });

    it('ignores URL parameters for unrecognized tokens', () => {
      setWindowLocation('?tokenA=5,10&unknownToken=20');
      createWrapper();

      expect(getLastEmittedFilters()).toEqual({ tokenA: ['5', '10'] });
    });

    it('ignores empty URL parameter values', () => {
      setWindowLocation('?tokenA=');
      createWrapper();

      expect(wrapper.emitted('filters-changed')).toBeUndefined();
      expect(findFilteredSearch().props('value')).toEqual([]);
    });

    it('does not push state on initialization with valid tokens', () => {
      setWindowLocation('?tokenA=5,10');
      createWrapper();

      expect(window.history.pushState).not.toHaveBeenCalled();
    });
  });

  describe('URL synchronization', () => {
    beforeEach(() => {
      setWindowLocation('?tab=test');
      createWrapper();
    });

    it('preserves existing URL parameters when adding filter', async () => {
      await updateToken('tokenA', ['5', '10']);

      expectUrlToBe('/?tab=test&tokenA=5%2C10');
    });

    it('handles multiple tokens in URL', async () => {
      await updateToken('tokenA', ['5']);
      await updateToken('tokenB', ['15', '20']);

      expectUrlToBe('/?tab=test&tokenA=5&tokenB=15%2C20');
    });

    it('removes token parameter on destroy while preserving others', async () => {
      await updateToken('tokenA', ['5', '10']);
      await updateToken('tokenB', ['15']);
      await destroyToken('tokenA');

      expectUrlToBe('/?tab=test&tokenB=15');
    });

    it('removes all filter parameters on clear', async () => {
      await updateToken('tokenA', ['5', '10']);
      await updateToken('tokenB', ['15']);
      await clearFilters();

      expectUrlToBe('/?tab=test');
    });
  });
});
