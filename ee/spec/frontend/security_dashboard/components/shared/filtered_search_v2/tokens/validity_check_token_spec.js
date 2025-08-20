import { GlFilteredSearchToken } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import ValidityCheckToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/validity_check_token.vue';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import eventHub from 'ee/security_dashboard/components/shared/filtered_search/event_hub';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

Vue.use(VueRouter);

describe('ValidityCheckToken', () => {
  let wrapper;
  let router;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = { data: ['UNKNOWN'], operator: '&&' },
    active = false,
    stubs,
    mountFn = shallowMountExtended,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(ValidityCheckToken, {
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

    it('shows the dropdown with correct options', () => {
      const findDropdownOptions = () =>
        wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

      expect(findDropdownOptions()).toEqual([
        'Active secret',
        'Inactive secret',
        'Possibly active secret',
      ]);
    });

    it.each([
      ['ACTIVE', 'Active secret'],
      ['INACTIVE', 'Inactive secret'],
      ['UNKNOWN', 'Possibly active secret'],
    ])('displays correct text for %s validity check', (value, expectedText) => {
      createWrapper({ value: { data: [value], operator: '&&' } });

      expect(wrapper.findByTestId('validity-check-token-placeholder').text()).toBe(expectedText);
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper();
      await clickDropdownItem('ACTIVE');
    });

    it('does not allow multiple selection', async () => {
      await clickDropdownItem('INACTIVE', 'UNKNOWN');

      expect(isOptionChecked('ACTIVE')).toBe(false);
      expect(isOptionChecked('INACTIVE')).toBe(false);
      expect(isOptionChecked('UNKNOWN')).toBe(true);
    });

    it('emits filters-changed event when a filter is selected', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      await clickDropdownItem('UNKNOWN');
      expect(spy).toHaveBeenCalledWith({
        validityCheck: 'UNKNOWN',
      });
    });

    it('does not show "+1 more" for single selections', () => {
      createWrapper({ value: { data: ['INACTIVE'], operator: '&&' } });

      const displayText = wrapper.findByTestId('validity-check-token-placeholder').text();
      expect(displayText).toBe('Inactive secret');
      expect(displayText).not.toContain('+1 more');
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

      expect(spy).toHaveBeenCalledWith({ validityCheck: undefined });
    });
  });

  describe('QuerystringSync component - validityCheck', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'validityCheck',
        value: ['UNKNOWN'],
        validValues: ['ACTIVE', 'INACTIVE', 'UNKNOWN'],
      });
    });

    it.each`
      emitted         | expected
      ${['ACTIVE']}   | ${['ACTIVE']}
      ${['INACTIVE']} | ${['INACTIVE']}
      ${['UNKNOWN']}  | ${['UNKNOWN']}
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
