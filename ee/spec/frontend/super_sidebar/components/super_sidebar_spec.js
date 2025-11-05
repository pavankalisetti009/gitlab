import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SuperSidebar from '~/super_sidebar/components/super_sidebar.vue';
import { sidebarState } from '~/super_sidebar/constants';
import { sidebarData as mockSidebarData } from '../mock_data';

describe('SuperSidebar component', () => {
  let wrapper;

  const findContextHeader = () => wrapper.find('#super-sidebar-context-header');
  const findTierBadge = () => wrapper.findByTestId('sidebar-tier-badge');

  const initialSidebarState = { ...sidebarState };
  const groupBillingPath = '/group/billing_page';

  const createWrapper = ({
    provide = {},
    sidebarData = mockSidebarData,
    sidebarState: state = {},
  } = {}) => {
    Object.assign(sidebarState, state);

    wrapper = shallowMountExtended(SuperSidebar, {
      provide: {
        showTrialWidget: false,
        projectStudioEnabled: false,
        showDuoAgentPlatformWidget: false,
        isAuthorized: false,
        requestCount: 0,
        showRequestAccess: false,
        hasRequested: false,
        ...provide,
      },
      propsData: {
        sidebarData,
      },
    });
  };

  beforeEach(() => {
    Object.assign(sidebarState, initialSidebarState);
  });

  describe('tier badge', () => {
    describe('showTierBadge computed property', () => {
      it('returns true when tier_badge_href is present', () => {
        createWrapper({
          sidebarData: {
            ...mockSidebarData,
            tier_badge_href: groupBillingPath,
          },
        });

        expect(wrapper.vm.showTierBadge).toBe(true);
      });

      it('returns false when is_free_plan is true but panel_type is not group or project', () => {
        createWrapper({
          sidebarData: {
            ...mockSidebarData,
            panel_type: 'user',
            is_free_plan: false,
          },
        });

        expect(wrapper.vm.showTierBadge).toBe(false);
      });
    });

    describe('tier badge rendering', () => {
      it('renders tier badge when showTierBadge is true and not in icon-only mode', async () => {
        createWrapper({
          sidebarData: {
            ...mockSidebarData,
            tier_badge_href: groupBillingPath,
            current_context_header: 'Test Group',
          },
        });

        await nextTick();

        expect(findTierBadge().exists()).toBe(true);
      });

      it('does not render tier badge when showTierBadge is false', async () => {
        createWrapper({ sidebarData: mockSidebarData });

        await nextTick();

        expect(findTierBadge().exists()).toBe(false);
      });

      it('does not render tier badge when in icon-only mode', async () => {
        createWrapper({
          provide: { projectStudioEnabled: true },
          sidebarData: {
            ...mockSidebarData,
            tier_badge_href: groupBillingPath,
            current_context_header: 'Test Group',
          },
          sidebarState: { isIconOnly: true },
        });

        await nextTick();

        expect(findContextHeader().exists()).toBe(false);
        expect(findTierBadge().exists()).toBe(false);
      });

      it('does not render tier badge when there is no context header', async () => {
        createWrapper({
          sidebarData: {
            ...mockSidebarData,
            tier_badge_href: groupBillingPath,
            current_context_header: null,
          },
        });

        await nextTick();

        expect(findContextHeader().exists()).toBe(false);
        expect(findTierBadge().exists()).toBe(false);
      });
    });
  });
});
