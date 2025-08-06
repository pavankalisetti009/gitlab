import { shallowMount } from '@vue/test-utils';

import FlowTriggersNew from 'ee/ai/duo_agents_platform/pages/flow_triggers/flow_triggers_new.vue';

describe('FlowTriggersNew', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMount(FlowTriggersNew);
  };

  beforeEach(() => {
    createWrapper();
  });

  it('renders with the correct title', () => {
    expect(wrapper.text()).toContain('New flow trigger');
  });
});
