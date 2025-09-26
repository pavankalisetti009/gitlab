import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogFlowsShow from 'ee/ai/catalog/pages/ai_catalog_flows_show.vue';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import { AI_CATALOG_FLOWS_EDIT_ROUTE } from 'ee/ai/catalog/router/constants';
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
  const findEditButton = () => wrapper.findComponent(GlButton);
  const findFlowDetails = () => wrapper.findComponent(AiCatalogFlowDetails);

  beforeEach(() => {
    createComponent();
  });

  it('renders page heading', () => {
    expect(findPageHeading().props('heading')).toBe(mockFlow.name);
  });

  it('renders edit button', () => {
    expect(findEditButton().text()).toBe('Edit');
    expect(findEditButton().props('to')).toEqual({
      name: AI_CATALOG_FLOWS_EDIT_ROUTE,
      params: { id: routeParams.id },
    });
  });

  it('renders project name and description', () => {
    expect(wrapper.text()).toContain(mockFlow.project.name);
    expect(wrapper.text()).toContain(mockFlow.description);
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
