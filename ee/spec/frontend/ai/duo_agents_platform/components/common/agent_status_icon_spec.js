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
      {
        status: 'CREATED',
        expectedStatusIcon: 'dash-circle',
        expectedStatusBorderColor: 'neutral',
        expectedStatusBackgroundColor: 'neutral',
      },
      {
        status: 'FINISHED',
        expectedStatusIcon: 'check',
        expectedStatusBorderColor: 'green',
        expectedStatusBackgroundColor: 'success',
      },
      {
        status: 'FAILED',
        expectedStatusIcon: 'error',
        expectedStatusBorderColor: 'red',
        expectedStatusBackgroundColor: 'danger',
      },
      {
        status: 'PAUSED',
        expectedStatusIcon: 'pause',
        expectedStatusBorderColor: 'neutral',
        expectedStatusBackgroundColor: 'neutral',
      },
    ];

    statusTestCases.forEach(
      ({
        status,
        expectedStatusIcon,
        expectedStatusBorderColor,
        expectedStatusBackgroundColor,
      }) => {
        it(`renders correct status for ${status}`, () => {
          createWrapper({ status });

          const icon = findStatusIcon();
          expect(icon.props('name')).toBe(expectedStatusIcon);

          const containerClasses = findStatusIconContainer().classes();
          expect(containerClasses).toContain(`gl-border-${expectedStatusBorderColor}-100`);
          expect(containerClasses).toContain(`gl-bg-status-${expectedStatusBackgroundColor}`);
        });
      },
    );
  });
});
