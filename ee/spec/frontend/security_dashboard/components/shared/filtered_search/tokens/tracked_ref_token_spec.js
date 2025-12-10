import {
  GlFilteredSearchToken,
  GlDropdownSectionHeader,
  GlDropdownDivider,
  GlBadge,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import TrackedRefToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/tracked_ref_token.vue';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filters/constants';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('TrackedRefToken', () => {
  let wrapper;

  const mockTrackedRefs = [
    { id: 'main', name: 'main', refType: 'branch', isDefault: true },
    { id: 'develop', name: 'develop', refType: 'branch', isDefault: false },
    { id: 'feature-1', name: 'feature-1', refType: 'branch', isDefault: false },
    { id: 'v1.0.0', name: 'v1.0.0', refType: 'tag', isDefault: false },
    { id: 'v2.0.0', name: 'v2.0.0', refType: 'tag', isDefault: false },
  ];

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = { data: [ALL_ID], operator: '=' },
    active = false,
    stubs,
    mountFn = shallowMountExtended,
    provide = {},
  } = {}) => {
    wrapper = mountFn(TrackedRefToken, {
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        trackedRefs: mockTrackedRefs,
        ...provide,
      },
      stubs: {
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findAllBadges = () => wrapper.findAllComponents(GlBadge);
  const findDropdownGroupHeaders = () => wrapper.findAllComponents(GlDropdownSectionHeader);
  const findDropdownDividers = () => wrapper.findAllComponents(GlDropdownDivider);
  const findDropdownOptions = () =>
    wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.props('text'));
  const isOptionChecked = (v) => wrapper.findByTestId(`suggestion-${v}`).props('selected') === true;

  const clickDropdownItem = async (...ids) => {
    ids.forEach((id) => {
      findFilteredSearchToken().vm.$emit('select', id);
    });

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  const allRefIdsExcept = (value) => {
    const exempt = Array.isArray(value) ? value : [value];
    return mockTrackedRefs.map((ref) => ref.id).filter((id) => !exempt.includes(id));
  };

  describe('default values', () => {
    it('has a defaultValues function that returns default branch ID when trackedRefs are provided', () => {
      expect(TrackedRefToken.defaultValues({ trackedRefs: mockTrackedRefs })).toEqual(['main']);
    });

    it('has a defaultValues function that returns empty array when no trackedRefs provided', () => {
      expect(TrackedRefToken.defaultValues({ trackedRefs: [] })).toEqual([]);
    });

    it('has a defaultValues function that returns empty array when trackedRefs is undefined', () => {
      expect(TrackedRefToken.defaultValues({})).toEqual([]);
    });
  });

  describe('transform filters', () => {
    it('transforms the filters correctly by filtering out ALL_ID', () => {
      expect(TrackedRefToken.transformFilters([ALL_ID, 'main', 'develop'])).toEqual({
        trackedRefIds: ['main', 'develop'],
      });
    });
  });

  describe('transform query params', () => {
    it('transforms the query params correctly', () => {
      expect(TrackedRefToken.transformQueryParams([])).toBe(ALL_ID);
      expect(TrackedRefToken.transformQueryParams([ALL_ID])).toBe(ALL_ID);
      expect(TrackedRefToken.transformQueryParams(['main', 'develop'])).toBe('main,develop');
      expect(TrackedRefToken.transformQueryParams(['main'])).toBe('main');
    });
  });

  describe('default view', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows the label with "All tracked refs"', () => {
      expect(findFilteredSearchToken().props('value')).toEqual({
        data: [ALL_ID],
        operator: '=',
      });
      expect(wrapper.text()).toContain('All tracked refs');
    });

    it('shows the dropdown with correct options', () => {
      expect(findDropdownOptions()).toEqual([
        'All tracked refs',
        ...mockTrackedRefs.map((ref) => ref.name),
      ]);
    });

    it('shows the dropdown with group headers for Branches and Tags', () => {
      const headers = findDropdownGroupHeaders().wrappers.map((header) => header.text());

      expect(headers).toEqual(['Branches', 'Tags']);
    });

    it('shows badges with correct icons for groups', () => {
      const badges = findAllBadges();

      expect(badges).toHaveLength(2);
      expect(badges.at(0).props('icon')).toBe('branch');
      expect(badges.at(1).props('icon')).toBe('tag');

      badges.wrappers.forEach((badge) => {
        expect(badge.attributes('aria-hidden')).toBe('true');
      });
    });

    it.each`
      refType       | refs
      ${'Branches'} | ${[{ id: 'main', name: 'main', refType: 'branch', isDefault: true }, { id: 'develop', name: 'develop', refType: 'branch', isDefault: false }]}
      ${'Tags'}     | ${[{ id: 'v1.0.0', name: 'v1.0.0', refType: 'tag', isDefault: false }, { id: 'v2.0.0', name: 'v2.0.0', refType: 'tag', isDefault: false }]}
    `(
      'renders only the "$refType" group when no other ref types are present',
      ({ refType, refs }) => {
        createWrapper({ provide: { trackedRefs: refs } });

        const headers = findDropdownGroupHeaders().wrappers.map((header) => header.text());

        expect(headers).toEqual([refType]);
        expect(findAllBadges()).toHaveLength(1);
      },
    );

    it('handles empty trackedRefs array', () => {
      createWrapper({ provide: { trackedRefs: [] } });

      expect(findDropdownOptions()).toEqual(['All tracked refs']);
      expect(findDropdownGroupHeaders()).toHaveLength(0);
    });

    it('renders dividers between groups', () => {
      expect(findDropdownDividers()).toHaveLength(2);
    });

    it('renders one divider when only branches are present', () => {
      const branchOnlyRefs = [
        { id: 'main', name: 'main', refType: 'branch', isDefault: true },
        { id: 'develop', name: 'develop', refType: 'branch', isDefault: false },
      ];
      createWrapper({ provide: { trackedRefs: branchOnlyRefs } });

      expect(findDropdownDividers()).toHaveLength(1);
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper({});
      // Ensure we start from a known state with ALL_ID selected
      await clickDropdownItem(ALL_ID);
    });

    it('selects "All tracked refs" and clears other selections when "All tracked refs" is selected', async () => {
      await clickDropdownItem('main', 'develop');
      expect(isOptionChecked('main')).toBe(true);
      expect(isOptionChecked('develop')).toBe(true);
      expect(isOptionChecked(ALL_ID)).toBe(false);

      await clickDropdownItem(ALL_ID);

      expect(isOptionChecked(ALL_ID)).toBe(true);
      allRefIdsExcept(ALL_ID).forEach((id) => {
        expect(isOptionChecked(id)).toBe(false);
      });
    });

    it('removes "All tracked refs" when a specific ref is selected', async () => {
      expect(isOptionChecked(ALL_ID)).toBe(true);

      await clickDropdownItem('main');

      expect(isOptionChecked(ALL_ID)).toBe(false);
      expect(isOptionChecked('main')).toBe(true);
    });

    it('allows multiple refs to be selected', async () => {
      await clickDropdownItem('main', 'develop', 'v1.0.0');

      expect(isOptionChecked('main')).toBe(true);
      expect(isOptionChecked('develop')).toBe(true);
      expect(isOptionChecked('v1.0.0')).toBe(true);
      expect(isOptionChecked(ALL_ID)).toBe(false);
    });

    it('deselects a ref when clicked again', async () => {
      await clickDropdownItem('main', 'develop');
      expect(isOptionChecked('main')).toBe(true);
      expect(isOptionChecked('develop')).toBe(true);

      await clickDropdownItem('main');

      expect(isOptionChecked('main')).toBe(false);
      expect(isOptionChecked('develop')).toBe(true);
    });

    it('defaults to "All tracked refs" when all selections are cleared', async () => {
      await clickDropdownItem('main');
      expect(isOptionChecked('main')).toBe(true);

      await clickDropdownItem('main');

      expect(isOptionChecked(ALL_ID)).toBe(true);
      allRefIdsExcept(ALL_ID).forEach((id) => {
        expect(isOptionChecked(id)).toBe(false);
      });
    });

    it('updates multiSelectValues prop when selecting refs', async () => {
      await clickDropdownItem('main', 'develop');

      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual(['main', 'develop']);
    });

    it('updates multiSelectValues prop when selecting ALL_ID', async () => {
      await clickDropdownItem('main', 'develop');
      await clickDropdownItem(ALL_ID);

      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([ALL_ID]);
    });

    it('updates multiSelectValues prop when deselecting all refs', async () => {
      await clickDropdownItem('main');
      await clickDropdownItem('main');

      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([ALL_ID]);
    });
  });

  describe('toggle text', () => {
    const findViewText = () => wrapper.findByTestId('toggle-text').text();

    beforeEach(async () => {
      createWrapper();
      // Ensure we start from a known state with ALL_ID selected
      await clickDropdownItem(ALL_ID);
    });

    it.each`
      selectedRefs                                            | expectedText
      ${ALL_ID}                                               | ${'All tracked refs'}
      ${['main']}                                             | ${'main'}
      ${['main', 'develop']}                                  | ${'main, develop'}
      ${['main', 'develop', 'feature-1']}                     | ${'main, develop +1 more'}
      ${['v1.0.0', 'v2.0.0']}                                 | ${'v1.0.0, v2.0.0'}
      ${['main', 'v1.0.0']}                                   | ${'main, v1.0.0'}
      ${['main', 'develop', 'feature-1', 'v1.0.0', 'v2.0.0']} | ${'main, develop +3 more'}
    `(
      'shows "$expectedText" when "$selectedRefs" are selected',
      async ({ selectedRefs, expectedText }) => {
        await clickDropdownItem(...selectedRefs);

        expect(findViewText()).toBe(expectedText);
      },
    );
  });

  describe('token value', () => {
    it('sets data to null when token is active', () => {
      createWrapper({ active: true, value: { data: ['main', 'develop'] } });

      expect(findFilteredSearchToken().props('value')).toEqual({
        data: null,
      });
    });

    it('sets data to selectedRefIds when token is not active', () => {
      createWrapper({ active: false, value: { data: ['main', 'develop'] } });

      expect(findFilteredSearchToken().props('value')).toEqual({
        data: ['main', 'develop'],
      });
    });
  });

  describe('component initialization', () => {
    it('initializes with provided value data', () => {
      createWrapper({ value: { data: ['main', 'develop'] } });
      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual(['main', 'develop']);
    });

    it('defaults to ALL_ID when no value data is provided', () => {
      createWrapper({ value: {} });
      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([ALL_ID]);
    });
  });
});
