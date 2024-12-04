import { nextTick } from 'vue';
import { GlDrawer, GlTab, GlTabs } from '@gitlab/ui';
import FindingsDrawer from 'ee/diffs/components/shared/findings_drawer.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { VULNERABILITY_TAB_NAMES } from 'ee/vulnerabilities/constants';
import FindingsDrawerDetails from 'ee/diffs/components/shared/findings_drawer_details.vue';
import {
  mockFindingDismissed,
  mockFindingDetected,
  mockProject,
  mockFindingsMultiple,
  mockFindingDetails,
} from 'jest/diffs/mock_data/findings_drawer';

describe('FindingsDrawer', () => {
  let wrapper;

  const findingDrawerProps = {
    drawer: { findings: [mockFindingDetected], index: 0 },
    project: mockProject,
  };

  const createWrapper = (
    findingDrawerOverrides = {},
    { vulnerabilityCodeFlow = false, mrVulnerabilityCodeFlow = false } = {},
  ) => {
    const propsData = {
      drawer: findingDrawerProps.drawer,
      project: findingDrawerProps.project,
      ...findingDrawerOverrides,
    };

    wrapper = mountExtended(FindingsDrawer, {
      propsData,
      provide: {
        glFeatures: { vulnerabilityCodeFlow, mrVulnerabilityCodeFlow },
      },
      stubs: {
        GlTabs,
      },
    });
  };

  const findPreviousButton = () => wrapper.findByTestId('findings-drawer-prev-button');
  const findNextButton = () => wrapper.findByTestId('findings-drawer-next-button');
  const findTitle = () => wrapper.findByTestId('findings-drawer-title');
  const findVulnerabilityDetails = () => wrapper.findComponent(FindingsDrawerDetails);
  const findVulnerabilityCodeFlow = () => wrapper.findByTestId('temp-code-flow');
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findAllTabs = () => wrapper.findAllComponents(GlTab);

  describe('General Rendering', () => {
    beforeEach(() => {
      createWrapper();
    });
    it('renders without errors', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('emits close event when gl-drawer emits close event', () => {
      wrapper.findComponent(GlDrawer).vm.$emit('close');
      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('matches the snapshot with dismissed badge', () => {
      expect(wrapper.element).toMatchSnapshot();
    });

    it('matches the snapshot with detected badge', () => {
      expect(wrapper.element).toMatchSnapshot();
    });
  });

  describe('Prev/Next Buttons with Multiple Items', () => {
    it('renders prev/next buttons when there are multiple items', () => {
      createWrapper({ drawer: { findings: mockFindingsMultiple, index: 0 } });
      expect(findPreviousButton().exists()).toBe(true);
      expect(findNextButton().exists()).toBe(true);
    });

    it('does not render prev/next buttons when there is only one item', () => {
      createWrapper({ drawer: { findings: [mockFindingDismissed], index: 0 } });
      expect(findPreviousButton().exists()).toBe(false);
      expect(findNextButton().exists()).toBe(false);
    });

    it('calls prev method on prev button click and loops correct drawerIndex', async () => {
      createWrapper({ drawer: { findings: mockFindingsMultiple, index: 0 } });
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[0].title}`);

      await findPreviousButton().trigger('click');
      await nextTick();
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[2].title}`);

      await findPreviousButton().trigger('click');
      await nextTick();
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[1].title}`);
    });

    it('calls next method on next button click', async () => {
      createWrapper({ drawer: { findings: mockFindingsMultiple, index: 0 } });
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[0].title}`);

      await findNextButton().trigger('click');
      await nextTick();
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[1].title}`);

      await findNextButton().trigger('click');
      await nextTick();
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[2].title}`);

      await findNextButton().trigger('click');
      await nextTick();
      expect(findTitle().text()).toBe(`Name ${mockFindingsMultiple[0].title}`);
    });
  });

  describe('when `vulnerabilityCodeFlow` and `mrVulnerabilityCodeFlow` are enabled', () => {
    describe('when `details` object is not empty', () => {
      beforeEach(() => {
        createWrapper(
          {
            drawer: {
              findings: [
                {
                  ...mockFindingDismissed,
                  details: mockFindingDetails,
                },
              ],
              index: 0,
            },
          },
          {
            vulnerabilityCodeFlow: true,
            mrVulnerabilityCodeFlow: true,
          },
        );
      });

      it('tabs should be shown', () => {
        expect(findAllTabs()).toHaveLength(2);
        expect(findTabs().exists()).toBe(true);
      });

      describe.each`
        title                                | finderFn                     | index
        ${VULNERABILITY_TAB_NAMES.DETAILS}   | ${findVulnerabilityDetails}  | ${0}
        ${VULNERABILITY_TAB_NAMES.CODE_FLOW} | ${findVulnerabilityCodeFlow} | ${1}
      `('Tabs', ({ title, finderFn, index }) => {
        it(`renders ${title} component`, () => {
          if (index === 0) {
            expect(finderFn().exists()).toBe(true);
          } else {
            expect(finderFn().text()).toBe(title);
          }
        });
      });
    });

    describe('when `details` object is empty', () => {
      beforeEach(() => {
        createWrapper(
          {},
          {
            vulnerabilityCodeFlow: true,
            mrVulnerabilityCodeFlow: true,
          },
        );
      });

      it('does not show the tabs', () => {
        expect(findTabs().exists()).toBe(false);
      });

      it('render `findVulnerabilityDetails` component without tabs', () => {
        expect(findVulnerabilityDetails().exists()).toBe(true);
      });
    });
  });

  describe('when `vulnerabilityCodeFlow` and `mrVulnerabilityCodeFlow` are disabled', () => {
    describe('when `details` object is not empty', () => {
      beforeEach(() => {
        createWrapper(
          {
            drawer: {
              findings: [
                {
                  ...mockFindingDismissed,
                  details: mockFindingDetails,
                },
              ],
              index: 0,
            },
          },
          {
            vulnerabilityCodeFlow: false,
            mrVulnerabilityCodeFlow: false,
          },
        );
      });

      it('does not show the tabs', () => {
        expect(findTabs().exists()).toBe(false);
      });

      it('render `findVulnerabilityDetails` component without tabs', () => {
        expect(findVulnerabilityDetails().exists()).toBe(true);
      });
    });

    describe('when `details` object is empty', () => {
      beforeEach(() => {
        createWrapper(
          {},
          {
            vulnerabilityCodeFlow: false,
            mrVulnerabilityCodeFlow: false,
          },
        );
      });

      it('does not show the tabs', () => {
        expect(findTabs().exists()).toBe(false);
      });

      it('render `findVulnerabilityDetails` component without tabs', () => {
        expect(findVulnerabilityDetails().exists()).toBe(true);
      });
    });
  });
});
