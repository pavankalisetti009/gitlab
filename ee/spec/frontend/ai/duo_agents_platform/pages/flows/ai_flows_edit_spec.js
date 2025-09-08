import { shallowMount } from '@vue/test-utils';

import AiFlowsEdit from 'ee/ai/duo_agents_platform/pages/flows/ai_flows_edit.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';

describe('AiFlowsEdit', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(AiFlowsEdit);
  };

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders PageHeading component', () => {
      expect(wrapper.findComponent(PageHeading).exists()).toBe(true);
    });
  });
});
