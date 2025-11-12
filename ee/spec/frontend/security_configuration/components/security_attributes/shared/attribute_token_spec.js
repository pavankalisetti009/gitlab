import { GlFilteredSearchSuggestion, GlFilteredSearchToken, GlIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import { OPERATOR_IS, OPERATOR_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AttributeToken from 'ee/security_configuration/security_attributes/components/shared/attribute_token.vue';
import { stubComponent } from 'helpers/stub_component';
import { getAttributeCategoryTokens } from 'ee/security_configuration/security_attributes/components/shared/attribute_utils';
import { mockSecurityAttributeCategories } from '../mock_data';

const mockConfig = getAttributeCategoryTokens(mockSecurityAttributeCategories)[0];
const expectedAttributeOptions = mockConfig.attributeOptions;

describe('Security attribute token', () => {
  let wrapper;

  const findSearchSuggestions = () => wrapper.findAllComponents(GlFilteredSearchSuggestion);
  const findSearchSuggestion = () => wrapper.findComponent(GlFilteredSearchSuggestion);
  const findSearchSuggestionAt = (i) => findSearchSuggestions().at(i);
  const findSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);

  const createComponent = ({
    value = { operator: OPERATOR_IS },
    active = true,
    config = {},
  } = {}) => {
    wrapper = shallowMountExtended(AttributeToken, {
      propsData: {
        config: {
          ...mockConfig,
          ...config,
        },
        value,
        active,
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `
          <div>
            <slot name="view-token"></slot>
            <slot name="suggestions"></slot>
          </div>
        `,
        }),
      },
    });
  };

  describe('attribute options', () => {
    beforeEach(() => createComponent());

    it('renders a search suggestion for each attribute option', () => {
      expect(findSearchSuggestions()).toHaveLength(expectedAttributeOptions.length);
    });

    it('passes the attribute name and value to the search suggestion', () => {
      expect(findSearchSuggestion().text()).toBe('Business Administrative');
      expect(findSearchSuggestion().props('value')).toBe(10);
    });
  });

  describe('attribute selection', () => {
    it('selects a single attribute', async () => {
      createComponent();

      findSearchToken().vm.$emit('select', 10);
      await nextTick();

      expect(findSearchToken().props('multiSelectValues')).toStrictEqual([10]);
      expect(wrapper.vm.toggleText).toBe('Business Administrative');
    });

    it('selects many attributes', async () => {
      createComponent({ value: { operator: OPERATOR_OR }, config: { multiSelect: true } });

      findSearchToken().vm.$emit('select', 10);
      findSearchToken().vm.$emit('select', 11);
      findSearchToken().vm.$emit('select', 8);
      findSearchToken().vm.$emit('select', 7);
      await nextTick();

      const selectedOption = findSearchSuggestionAt(0); // 10
      const unselectedOption = findSearchSuggestionAt(2); // 9

      expect(selectedOption.text()).toBe('Business Administrative');
      expect(selectedOption.findComponent(GlIcon).classes()).not.toContain('gl-invisible');
      expect(unselectedOption.text()).toBe('Business Operational');
      expect(unselectedOption.findComponent(GlIcon).classes()).toContain('gl-invisible');
      expect(findSearchToken().props('multiSelectValues')).toStrictEqual([10, 11, 8, 7]);
      expect(wrapper.vm.toggleText).toBe('Business Administrative, Business Critical +2 more');
    });
  });
});
