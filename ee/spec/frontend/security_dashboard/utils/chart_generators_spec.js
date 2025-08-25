import { generateVulnerabilitiesForSeverityPanels } from 'ee/security_dashboard/utils/chart_generators';

describe('Security Dashboard - Chart Utils', () => {
  const severities = ['Critical', 'High', 'Medium', 'Low', 'Info', 'Unknown'];

  describe('generateVulnerabilitiesForSeverityPanels', () => {
    const filters = {
      reportType: ['SAST'],
      projectId: ['1'],
    };
    const widthConstant = 2;
    const expected = severities.map((severity, index) => ({
      id: severity.toLowerCase(),
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
      const panels = generateVulnerabilitiesForSeverityPanels(filters);
      expect(panels).toMatchObject(expected);
    });
  });
});
