import { shallowMount } from '@vue/test-utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogFlowsShow from 'ee/ai/catalog/pages/ai_catalog_flows_show.vue';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import AiCatalogItemActions from 'ee/ai/catalog/components/ai_catalog_item_actions.vue';
import { TRACK_EVENT_TYPE_FLOW, TRACK_EVENT_VIEW_AI_CATALOG_ITEM } from 'ee/ai/catalog/constants';
import { mockFlow } from '../mock_data';

describe('AiCatalogFlowsShow', () => {
  let wrapper;

  const defaultProps = {
    aiCatalogFlow: mockFlow,
  };

  const routeParams = { id: '1' };
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = () => {
    wrapper = shallowMount(AiCatalogFlowsShow, {
      propsData: {
        ...defaultProps,
      },
      mocks: {
        $route: {
          params: routeParams,
        },
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findItemActions = () => wrapper.findComponent(AiCatalogItemActions);
  const findFlowDetails = () => wrapper.findComponent(AiCatalogFlowDetails);

  beforeEach(() => {
    createComponent();
  });

  it('renders page heading', () => {
    expect(findPageHeading().props('heading')).toBe(mockFlow.name);
  });

  it('renders item actions', () => {
    expect(findItemActions().props('item')).toBe(mockFlow);
  });

  it('renders flow details', () => {
    expect(findFlowDetails().props('item')).toBe(mockFlow);
  });

  describe('tracking events', () => {
    it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_ITEM} event on mount`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
        { label: TRACK_EVENT_TYPE_FLOW },
        undefined,
      );
    });
  });
});
