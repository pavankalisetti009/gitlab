import {
  getRedirectConfirmationMessage,
  projectSettingsValidator,
} from 'ee/product_analytics/onboarding/components/providers/utils';

describe('product analytics onboarding provider utils', () => {
  describe('getRedirectConfirmationMessage', () => {
    it('should return the correct confirmation message', () => {
      const instructionLine1Message = 'Please go to %{analyticsSettingsLink} and do the thing.';
      const projectAnalyticsSettingsPath = '/project/settings/analytics';

      expect(
        getRedirectConfirmationMessage(instructionLine1Message, projectAnalyticsSettingsPath),
      ).toBe(
        `<p>Please go to <a href="/project/settings/analytics" target="_blank" rel="noopener noreferrer nofollow">Project &gt; Settings &gt; Analytics &gt; Data sources</a> and do the thing.</p><p>Then, return to this page and continue with the setup.</p>`,
      );
    });
  });

  describe('projectSettingsValidator', () => {
    const validProp = {
      productAnalyticsConfiguratorConnectionString: 'https://test:test@configurator.example.com',
      productAnalyticsDataCollectorHost: 'https://collector.example.com',
      cubeApiBaseUrl: 'https://cube.example.com',
      cubeApiKey: '123-some-cube-key',
    };
    const { cubeApiKey, ...propMissingCube } = validProp;

    const testCases = [
      ['valid settings', validProp, true],
      ['null value', { ...validProp, cubeApiKey: null }, true],
      ['missing property', propMissingCube, false],
      ['unexpected property', { ...validProp, someUnexpectedProp: 'test' }, false],
      ['invalid value type', { ...validProp, cubeApiKey: 123 }, false],
      ['empty object', {}, false],
    ];

    it.each(testCases)('%s', (_, prop, expected) => {
      expect(projectSettingsValidator(prop)).toBe(expected);
    });
  });
});
