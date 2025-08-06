import { shallowMount } from '@vue/test-utils';

import FlowTriggersShow from 'ee/ai/duo_agents_platform/pages/flow_triggers/flow_triggers_show.vue';

describe('FlowTriggersShow', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMount(FlowTriggersShow);
  };

  beforeEach(() => {
    createWrapper();
  });

  it('renders with the correct title', () => {
    expect(wrapper.text()).toContain('Flow trigger details');
  });
});
