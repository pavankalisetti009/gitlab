import { ref } from 'vue';
import { GlExperimentBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from 'ee/ai/catalog/constants';
import AiCatalogAgentHeader from 'ee/ai/catalog/components/ai_catalog_agent_header.vue';

const mockShowBetaBadge = ref(false);

jest.mock('ee/ai/duo_agents_platform/composables/use_ai_beta_badge', () => ({
  useAiBetaBadge: jest.fn(() => ({
    showBetaBadge: mockShowBetaBadge,
  })),
}));

describe('AiCatalogAgentHeader component', () => {
  let wrapper;

  const defaultProps = {
    heading: 'Test Agent',
    description: 'This is a test agent description',
    itemType: AI_CATALOG_TYPE_AGENT,
  };

  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogAgentHeader, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('badge rendering', () => {
    it.each`
      itemType                            | showBeta | shouldRender | badgeType
      ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${false} | ${false}     | ${null}
      ${AI_CATALOG_TYPE_AGENT}            | ${true}  | ${true}      | ${'beta'}
      ${AI_CATALOG_TYPE_AGENT}            | ${false} | ${false}     | ${null}
      ${null}                             | ${false} | ${false}     | ${null}
    `(
      'with itemType=$itemType and showBeta=$showBeta, renders=$shouldRender badge of type=$badgeType',
      ({ itemType, showBeta, shouldRender, badgeType }) => {
        mockShowBetaBadge.value = showBeta;
        createComponent({ itemType });
        const badge = findExperimentBadge();
        expect(badge.exists()).toBe(shouldRender);
        if (shouldRender) {
          expect(badge.props('type')).toBe(badgeType);
        }
      },
    );
  });
});
