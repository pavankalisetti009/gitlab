import { s__, sprintf } from '~/locale';

export function getRedirectConfirmationMessage(
  instructionLine1Message,
  projectAnalyticsSettingsPath,
) {
  return sprintf(
    `<p>%{instructionLine1}</p><p>%{instructionLine2}</p>`,
    {
      instructionLine1: sprintf(
        instructionLine1Message,
        {
          analyticsSettingsLink: `<a href="${projectAnalyticsSettingsPath}" target="_blank" rel="noopener noreferrer nofollow">Project &gt; Settings &gt; Analytics &gt; Data sources</a>`,
        },
        false,
      ),
      instructionLine2: s__(
        'ProductAnalytics|Then, return to this page and continue with the setup.',
      ),
    },
    false,
  );
}

export function projectSettingsValidator(prop) {
  const expected = [
    'productAnalyticsConfiguratorConnectionString',
    'productAnalyticsDataCollectorHost',
    'cubeApiBaseUrl',
    'cubeApiKey',
  ];

  return (
    Object.keys(prop).length === expected.length &&
    expected.every((key) => key in prop && (typeof prop[key] === 'string' || prop[key] === null))
  );
}
