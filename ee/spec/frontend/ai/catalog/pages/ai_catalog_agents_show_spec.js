import { shallowMount } from '@vue/test-utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import AiCatalogAgentsShow from 'ee/ai/catalog/pages/ai_catalog_agents_show.vue';
import AiCatalogItemActions from 'ee/ai/catalog/components/ai_catalog_item_actions.vue';
import AiCatalogItemView from 'ee/ai/catalog/components/ai_catalog_item_view.vue';
import { TRACK_EVENT_TYPE_AGENT, TRACK_EVENT_VIEW_AI_CATALOG_ITEM } from 'ee/ai/catalog/constants';
import { mockAgent } from '../mock_data';

describe('AiCatalogAgentsShow', () => {
  let wrapper;

  const defaultProps = {
    aiCatalogAgent: mockAgent,
  };

  const routeParams = { id: '1' };
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = () => {
    wrapper = shallowMount(AiCatalogAgentsShow, {
      propsData: {
        ...defaultProps,
      },
      provide: {
        isGlobal: false,
        projectId: '1',
      },
      mocks: {
        $route: {
          params: routeParams,
        },
      },
    });
  };

  const findItemActions = () => wrapper.findComponent(AiCatalogItemActions);
  const findItemView = () => wrapper.findComponent(AiCatalogItemView);

  beforeEach(() => {
    createComponent();
  });

  it('renders item actions', () => {
    expect(findItemActions().props('item')).toBe(mockAgent);
  });

  it('renders item view', () => {
    expect(findItemView().props('item')).toBe(mockAgent);
  });

  describe('tracking events', () => {
    it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_ITEM} event on mount`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
        { label: TRACK_EVENT_TYPE_AGENT },
        undefined,
      );
    });
  });
});
