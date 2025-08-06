import { shallowMount } from '@vue/test-utils';

import FlowTriggersIndex from 'ee/ai/duo_agents_platform/pages/flow_triggers/flow_triggers_index.vue';

describe('FlowTriggersIndex', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMount(FlowTriggersIndex);
  };

  beforeEach(() => {
    createWrapper();
  });

  it('renders with the correct title', () => {
    expect(wrapper.text()).toContain('Flow triggers');
  });
});
