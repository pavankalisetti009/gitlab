import { s__ } from '~/locale';

const DAST_VARIABLES = {
  DAST_ACTIVE_SCAN_TIMEOUT: {
    type: 'Duration string',
    example: '3h',
    description: s__(
      'DastProfiles|The maximum amount of time to wait for the active scan phase of the scan to complete. Defaults to 3h.',
    ),
  },
  DAST_ACTIVE_SCAN_WORKER_COUNT: {
    type: 'number',
    example: 3,
    description: s__('DastProfiles|The number of active checks to run in parallel. Defaults to 3.'),
  },
  DAST_AUTH_AFTER_LOGIN_ACTIONS: {
    type: 'string',
    example: 'click(on=id:remember-me),click(on=css:.continue)',
    description: s__(
      'DastProfiles|A comma-separated list of actions to be run after login but before login verification. Currently supports `click` actions.',
    ),
  },
  DAST_AUTH_BEFORE_LOGIN_ACTIONS: {
    type: 'selector',
    example: 'css:.user,id:show-login-form',
    description: s__(
      'DastProfiles|A comma-separated list of selectors representing elements to click on prior to entering the DAST_AUTH_USERNAME and DAST_AUTH_PASSWORD into the login form.',
    ),
  },
  DAST_AUTH_CLEAR_INPUT_FIELDS: {
    type: 'boolean',
    example: true,
    description: s__(
      'DastProfiles|Disables clearing of username and password fields before attempting manual login. Set to false by default.',
    ),
  },
};

export default DAST_VARIABLES;
