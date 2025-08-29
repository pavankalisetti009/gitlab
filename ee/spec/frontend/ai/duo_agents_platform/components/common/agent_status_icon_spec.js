import { GlIcon } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import AgentStatusIcon from 'ee/ai/duo_agents_platform/components/common/agent_status_icon.vue';

describe('AgentStatusIcon', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = mount(AgentStatusIcon, {
      propsData: {
        ...props,
      },
      stubs: {
        GlIcon,
      },
    });
  };

  const findStatusIcon = () => wrapper.findComponent(GlIcon);
  const findStatusIconContainer = () => wrapper.find('span');

  describe('when status is provided', () => {
    it('renders the status icon when valid', () => {
      createWrapper({ status: 'FINISHED' });

      expect(findStatusIcon().exists()).toBe(true);
    });
  });

  describe('when status is not provided', () => {
    it('renders the status icon with default created state', () => {
      createWrapper();

      const icon = findStatusIcon();
      expect(icon.exists()).toBe(true);
      expect(icon.props('name')).toBe('dash-circle');
    });
  });

  describe('with different item statuses', () => {
    const statusTestCases = [
      { status: 'CREATED', expectedStatusIcon: 'dash-circle', expectedStatusColor: 'neutral' },
      { status: 'FINISHED', expectedStatusIcon: 'check', expectedStatusColor: 'green' },
      { status: 'FAILED', expectedStatusIcon: 'error', expectedStatusColor: 'red' },
      { status: 'PAUSED', expectedStatusIcon: 'pause', expectedStatusColor: 'neutral' },
    ];

    statusTestCases.forEach(({ status, expectedStatusIcon, expectedStatusColor }) => {
      it(`renders correct status for ${status}`, () => {
        createWrapper({ status });

        const icon = findStatusIcon();
        expect(icon.props('name')).toBe(expectedStatusIcon);

        const containerClasses = findStatusIconContainer().classes();
        expect(containerClasses).toContain(`gl-border-${expectedStatusColor}-100`);
        expect(containerClasses).toContain(`gl-bg-${expectedStatusColor}-100`);
      });
    });
  });
});
