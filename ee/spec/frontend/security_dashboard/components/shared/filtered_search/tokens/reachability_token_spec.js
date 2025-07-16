import { GlFilteredSearchToken } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import ReachabilityToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/reachability_token.vue';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import eventHub from 'ee/security_dashboard/components/shared/filtered_search/event_hub';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

Vue.use(VueRouter);

describe('ReachabilityToken', () => {
  let wrapper;
  let router;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = { data: ['IN_USE'], operator: '&&' },
    active = false,
    stubs,
    mountFn = shallowMountExtended,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(ReachabilityToken, {
      router,
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
      },
      stubs: {
        QuerystringSync: true,
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findQuerystringSync = () => wrapper.findComponent(QuerystringSync);
  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const isOptionChecked = (v) => wrapper.findByTestId(`suggestion-${v}`).props('selected') === true;

  const clickDropdownItem = async (...ids) => {
    await Promise.all(
      ids.map((id) => {
        findFilteredSearchToken().vm.$emit('select', id);
        return nextTick();
      }),
    );

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  const allOptionsExcept = (value) => {
    const exempt = Array.isArray(value) ? value : [value];

    return wrapper.vm.$options.items.map((i) => i.value).filter((i) => !exempt.includes(i));
  };

  describe('default view', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows the label', () => {
      expect(findFilteredSearchToken().props('value')).toEqual({
        data: 'IN_USE',
        operator: '&&',
      });
      expect(wrapper.findByTestId('reachability-token-placeholder').text()).toBe('Yes');
    });

    it('shows the dropdown with correct options', () => {
      const findDropdownOptions = () =>
        wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

      expect(findDropdownOptions()).toEqual(['Yes', 'Not found', 'Not available']);
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper();
      await clickDropdownItem('IN_USE');
    });

    it('does not allow multiple selection', async () => {
      await clickDropdownItem('IN_USE', 'NOT_FOUND');

      expect(isOptionChecked('IN_USE')).toBe(false);
      expect(isOptionChecked('UNKNOWN')).toBe(false);
      expect(isOptionChecked('NOT_FOUND')).toBe(true);
    });

    it('emits filters-changed event when a filter is selected', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      await clickDropdownItem('UNKNOWN');
      expect(spy).toHaveBeenCalledWith({
        reachability: 'UNKNOWN',
      });
    });
  });

  describe('on clear', () => {
    beforeEach(async () => {
      createWrapper();
      await nextTick();
    });

    it('emits filters-changed event and resets selected values', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      findFilteredSearchToken().vm.$emit('destroy');
      await nextTick();

      expect(spy).toHaveBeenCalledWith({ reachability: undefined });
    });
  });

  describe('QuerystringSync component - reportType', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'reachability',
        value: ['IN_USE'],
        validValues: ['IN_USE', 'NOT_FOUND', 'UNKNOWN'],
      });
    });

    it.each`
      emitted          | expected
      ${['IN_USE']}    | ${['IN_USE']}
      ${['NOT_FOUND']} | ${['NOT_FOUND']}
      ${['UNKNOWN']}   | ${['UNKNOWN']}
    `('restores selected items - $emitted', async ({ emitted, expected }) => {
      findQuerystringSync().vm.$emit('input', emitted);
      await nextTick();

      expected.forEach((item) => {
        expect(isOptionChecked(item)).toBe(true);
      });

      allOptionsExcept(expected).forEach((item) => {
        expect(isOptionChecked(item)).toBe(false);
      });
    });
  });
});
