import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

const DAST_VARIABLES = {
  DAST_ACTIVE_SCAN_TIMEOUT: {
    type: 'Duration string',
    example: '3h',
    name: s__('DastProfiles|Active scan timeout'),
    description: {
      message: s__(
        'DastProfiles|The maximum amount of time to wait for the active scan phase of the scan to complete. Defaults to 3h.',
      ),
    },
  },
  DAST_ACTIVE_SCAN_WORKER_COUNT: {
    type: 'number',
    example: 3,
    name: s__('DastProfiles|Active scan worker count'),
    description: {
      message: s__('DastProfiles|The number of active checks to run in parallel. Defaults to 3.'),
    },
  },
  DAST_AUTH_AFTER_LOGIN_ACTIONS: {
    type: 'string',
    example: 'click(on=id:remember-me),click(on=css:.continue)',
    name: s__('DastProfiles|After-login actions'),
    description: {
      message: s__(
        'DastProfiles|A comma-separated list of actions to be run after login but before login verification. Currently supports `click` actions.',
      ),
    },
  },
  DAST_AUTH_BEFORE_LOGIN_ACTIONS: {
    type: 'selector',
    example: 'css:.user,id:show-login-form',
    name: s__('DastProfiles|Before-login actions'),
    description: {
      message: s__(
        'DastProfiles|A comma-separated list of selectors representing elements to click on prior to entering the DAST_AUTH_USERNAME and DAST_AUTH_PASSWORD into the login form.',
      ),
    },
  },
  DAST_AUTH_CLEAR_INPUT_FIELDS: {
    type: 'boolean',
    example: true,
    name: s__('DastProfiles|Clear input fields'),
    description: {
      message: s__(
        'DastProfiles|Disables clearing of username and password fields before attempting manual login. Set to false by default.',
      ),
    },
  },
  DAST_CHECKS_TO_EXCLUDE: {
    type: 'string',
    example: '552.2,78.1',
    name: s__('DastProfiles|Excluded checks'),
    description: {
      message: s__(
        'DastProfiles|Comma-separated list of check identifiers to use for the scan. For identifiers, see %{linkStart}vulnerability checks.%{linkEnd}',
      ),
      path: helpPagePath('user/application_security/dast/browser/checks/index'),
    },
  },
};

export default DAST_VARIABLES;
