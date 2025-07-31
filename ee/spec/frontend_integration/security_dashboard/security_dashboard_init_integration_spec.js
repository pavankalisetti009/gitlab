import initSecurityDashboard from 'ee/security_dashboard/security_dashboard_init';
import {
  DASHBOARD_TYPE_GROUP,
  DASHBOARD_TYPE_INSTANCE,
  DASHBOARD_TYPE_PROJECT,
} from 'ee/security_dashboard/constants';
import setWindowLocation from 'helpers/set_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';

const EMPTY_DIV = document.createElement('div');

const TEST_DATASET = {
  link: '/test/link',
  svgPath: '/test/no_changes_state.svg',
  emptyStateSvgPath: '/test/empty_state.svg',
  hasProjects: 'true',
};

describe('Security Dashboard', () => {
  let vm;
  let root;

  beforeEach(() => {
    root = document.createElement('div');
    document.body.appendChild(root);

    setWindowLocation(`${TEST_HOST}/-/security/dashboard`);

    // We currently have feature flag logic that needs gon.features to be set
    // It is set to false by default, so the original test's (where there was no feature flag) snapshot is preserved.
    window.gon.features = {
      groupSecurityDashboardNew: false,
    };

    // Set up abilities
    window.gon.abilities = {
      accessAdvancedVulnerabilityManagement: false,
    };
  });

  afterEach(() => {
    if (vm) {
      vm.$destroy();
    }
    root.remove();
  });

  const createComponent = async ({ data, type }) => {
    const el = document.createElement('div');
    Object.assign(el.dataset, { ...TEST_DATASET, ...data });
    root.appendChild(el);
    vm = await initSecurityDashboard(el, type);
  };

  const createEmptyComponent = async () => {
    vm = await initSecurityDashboard(null, null);
  };

  describe('default states', () => {
    it('sets up group-level', async () => {
      await createComponent({ data: { groupFullPath: '/test/' }, type: DASHBOARD_TYPE_GROUP });

      expect(root).toMatchSnapshot();
    });

    describe('`groupSecurityDashboardNew` feature flag enabled', () => {
      beforeEach(() => {
        window.gon.features.groupSecurityDashboardNew = true;
      });

      it('sets up old dashboard when elastic search is disabled', async () => {
        await createComponent({ data: { groupFullPath: '/test/' }, type: DASHBOARD_TYPE_GROUP });

        expect(root).toMatchSnapshot();
      });

      it('sets up new dashboard when elastic search is enabled', async () => {
        window.gon.abilities.accessAdvancedVulnerabilityManagement = true;

        await createComponent({ data: { groupFullPath: '/test/' }, type: DASHBOARD_TYPE_GROUP });

        expect(root).toMatchSnapshot();
      });
    });

    it('sets up project-level', async () => {
      await createComponent({
        data: {
          projectFullPath: '/test/project',
          hasVulnerabilities: 'true',
          securityConfigurationPath: '/test/configuration',
        },
        type: DASHBOARD_TYPE_PROJECT,
      });

      expect(root).toMatchSnapshot();
    });

    describe('`projectSecurityDashboardNew` feature flag enabled', () => {
      beforeEach(() => {
        window.gon.features.projectSecurityDashboardNew = true;
      });

      it('sets up old dashboard when elastic search is disabled', async () => {
        await createComponent({
          data: {
            projectFullPath: '/test/project',
            hasVulnerabilities: 'true',
            securityConfigurationPath: '/test/configuration',
          },
          type: DASHBOARD_TYPE_PROJECT,
        });

        expect(root).toMatchSnapshot();
      });

      it('sets up new dashboard when elastic search is enabled', async () => {
        window.gon.abilities.accessAdvancedVulnerabilityManagement = true;

        await createComponent({
          data: {
            projectFullPath: '/test/project',
            hasVulnerabilities: 'true',
            securityConfigurationPath: '/test/configuration',
          },
          type: DASHBOARD_TYPE_PROJECT,
        });

        expect(root).toMatchSnapshot();
      });
    });

    it('sets up instance-level', async () => {
      await createComponent({
        data: { instanceDashboardSettingsPath: '/instance/settings_page' },
        type: DASHBOARD_TYPE_INSTANCE,
      });

      expect(root).toMatchSnapshot();
    });
  });

  describe('error states', () => {
    it('does not have an element', async () => {
      await createEmptyComponent();

      expect(root).toStrictEqual(EMPTY_DIV);
    });

    it('has unavailable pages', async () => {
      await createComponent({ data: { isUnavailable: true } });

      expect(root).toMatchSnapshot();
    });
  });
});
