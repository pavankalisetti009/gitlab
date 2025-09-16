import { generateVulnerabilitiesForSeverityPanels } from 'ee/security_dashboard/utils/chart_generators';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';

describe('Security Dashboard - Chart Utils', () => {
  const severities = ['Critical', 'High', 'Medium', 'Low', 'Info', 'Unknown'];

  describe('generateVulnerabilitiesForSeverityPanels', () => {
    const mockComponent = { name: 'MockComponent', template: '<div>Mock Component</div>' };
    const filters = {
      reportType: ['SAST'],
      projectId: ['1'],
    };
    const widthConstant = 2;

    const expected = severities.map((severity, index) => ({
      id: severity.toLowerCase(),
      component: markRaw(mockComponent),
      componentProps: {
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
        panelComponent: mockComponent,
        filters,
      });

      expect(panels).toMatchObject(expected);
    });
  });
});
