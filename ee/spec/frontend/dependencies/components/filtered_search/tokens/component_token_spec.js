import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
  GlIntersperse,
  GlLoadingIcon,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

const TEST_COMPONENTS = [
  { id: 'gid://gitlab/Component/1', name: 'activerecord' },
  { id: 'gid://gitlab/Component/2', name: 'rails' },
  { id: 'gid://gitlab/Component/3', name: 'rack' },
];

jest.mock('~/alert');

describe('ee/dependencies/components/filtered_search/tokens/component_token.vue', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(ComponentToken, {
      propsData: {
        config: {
          multiSelect: true,
        },
        value: {},
        active: false,
        ...propsData,
      },
      stubs: {
        GlIntersperse,
      },
    });
  };

  const isLoadingSuggestions = () => wrapper.findComponent(GlLoadingIcon).exists();
  const findSuggestions = () => wrapper.findAllComponents(GlFilteredSearchSuggestion);
  const findFirstSearchSuggestionIcon = () => findSuggestions().at(0).findComponent(GlIcon);
  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const selectComponent = (component) => {
    findFilteredSearchToken().vm.$emit('select', component);
    return nextTick();
  };
  const searchForComponent = (searchTerm = '') => {
    findFilteredSearchToken().vm.$emit('input', { data: searchTerm });
    return waitForPromises();
  };

  describe('when the component is initially rendered', () => {
    it('shows a loading indicator while fetching the list of licenses', () => {
      createComponent();

      expect(isLoadingSuggestions()).toBe(true);
    });

    it.each([
      { active: true, expectedValue: { data: null } },
      { active: false, expectedValue: { data: [] } },
    ])(
      'passes "$expectedValue" to the search-token when the dropdown is open: "$active"',
      async ({ active, expectedValue }) => {
        createComponent({
          propsData: {
            active,
            value: { data: [] },
          },
        });

        await waitForPromises();

        expect(findFilteredSearchToken().props('value')).toEqual(expectedValue);
      },
    );
  });

  describe('when the list of components have been fetched successfully', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('does not show an error message', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('does not show a loading indicator', () => {
      expect(isLoadingSuggestions()).toBe(false);
    });

    it('shows a list of suggested components', () => {
      const suggestions = findSuggestions();

      expect(suggestions).toHaveLength(TEST_COMPONENTS.length);

      expect(suggestions.at(0).text()).toBe(TEST_COMPONENTS[0].name);
      expect(suggestions.at(1).text()).toBe(TEST_COMPONENTS[1].name);
      expect(suggestions.at(2).text()).toBe(TEST_COMPONENTS[2].name);
    });

    describe('when a user selects components to be filtered', () => {
      it('displays a check-icon next to the selected component', async () => {
        expect(findFirstSearchSuggestionIcon().classes()).toContain('gl-invisible');

        await selectComponent(TEST_COMPONENTS[0]);

        expect(findFirstSearchSuggestionIcon().classes()).not.toContain('gl-invisible');
      });

      it('shows a comma seperated list of selected component', async () => {
        await selectComponent(TEST_COMPONENTS[0]);
        await selectComponent(TEST_COMPONENTS[1]);

        expect(wrapper.findByTestId('selected-components').text()).toMatchInterpolatedText(
          `${TEST_COMPONENTS[0].name}, ${TEST_COMPONENTS[1].name}`,
        );
      });

      it(`emits the selected components' names`, async () => {
        const tokenData = {
          id: 'component_names',
          type: 'component',
          operator: '=',
        };

        const expectedNames = TEST_COMPONENTS.map((component) => component.name);

        await selectComponent(TEST_COMPONENTS[0]);
        await selectComponent(TEST_COMPONENTS[1]);
        await selectComponent(TEST_COMPONENTS[2]);

        findFilteredSearchToken().vm.$emit('input', tokenData);

        expect(wrapper.emitted('input')).toEqual([
          [
            {
              ...tokenData,
              data: expectedNames,
            },
          ],
        ]);
      });
    });

    describe('when a user enters a search term', () => {
      it('shows the filtered list of components', async () => {
        await searchForComponent(TEST_COMPONENTS[0].name);

        expect(findSuggestions()).toHaveLength(1);
        expect(findSuggestions().at(0).text()).toBe(TEST_COMPONENTS[0].name);
      });

      it('shows the already selected components in the filtered list', async () => {
        await selectComponent(TEST_COMPONENTS[0]);
        await searchForComponent(TEST_COMPONENTS[1].name);

        expect(findSuggestions()).toHaveLength(2);
        expect(findSuggestions().at(0).text()).toBe(TEST_COMPONENTS[0].name);
        expect(findSuggestions().at(1).text()).toBe(TEST_COMPONENTS[1].name);
      });
    });
  });
});
