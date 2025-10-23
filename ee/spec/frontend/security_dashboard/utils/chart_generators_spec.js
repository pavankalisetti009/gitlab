import { generateVulnerabilitiesForSeverityPanels } from 'ee/security_dashboard/utils/chart_generators';
import VulnerabilitiesForSeverityWrapper from 'ee/security_dashboard/components/shared/vulnerabilities_for_severity_wrapper.vue';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';

describe('Security Dashboard - Chart Utils', () => {
  const severities = ['Critical', 'High', 'Medium', 'Low', 'Info', 'Unknown'];

  describe('generateVulnerabilitiesForSeverityPanels', () => {
    const filters = {
      reportType: ['SAST'],
      projectId: ['1'],
    };
    const scope = 'project';
    const widthConstant = 2;

    const expected = severities.map((severity, index) => ({
      id: severity.toLowerCase(),
      component: markRaw(VulnerabilitiesForSeverityWrapper),
      componentProps: {
        scope,
        severity: severity.toLowerCase(),
        filters,
      },
      gridAttributes: {
        width: widthConstant,
        height: 1,
        yPos: 0,
        xPos: widthConstant * index,
      },
    }));

    it('returns array with panels config for each severity', () => {
      const panels = generateVulnerabilitiesForSeverityPanels({
        scope,
        filters,
      });

      expect(panels).toMatchObject(expected);
    });
  });
});
