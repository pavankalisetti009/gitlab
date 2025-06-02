import { nextTick } from 'vue';
import { GlTableLite, GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import WorkspacesAgentAvailabilityApp from 'ee_component/workspaces/admin_settings/pages/app.vue';
import AvailabilityPopover from 'ee_component/workspaces/admin_settings/components/availability_popover.vue';

const MOCK_ORG_ID = 'gid://gitlab/Organizations::Organization/1';

describe('workspaces/admin_settings/pages/app.vue', () => {
  let wrapper;

  const buildWrapper = () => {
    wrapper = mountExtended(WorkspacesAgentAvailabilityApp, {
      provide: {
        organizationId: MOCK_ORG_ID,
        defaultExpanded: true,
      },
    });
  };
  const findAgentsTable = () => wrapper.findComponent(GlTableLite);
  const findAvailabilityPopover = () => wrapper.findComponent(AvailabilityPopover);

  describe('default', () => {
    beforeEach(async () => {
      buildWrapper();
      await nextTick();
    });

    it('renders agents table', () => {
      expect(findAgentsTable().exists()).toBe(true);
    });

    it('renders popover in availability header column', () => {
      expect(findAvailabilityPopover().exists()).toBe(true);
    });

    it('renders agent name with link to the agent page', () => {
      const nameElement = wrapper.findComponent(GlLink);
      expect(nameElement.exists()).toBe(true);
      // TODO: update once we implement query: https://gitlab.com/gitlab-org/gitlab/-/issues/513370
      expect(nameElement.attributes('href')).toBe('#');
    });
  });
});
