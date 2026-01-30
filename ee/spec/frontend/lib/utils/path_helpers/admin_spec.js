// To run this spec locally first run `bundle exec rake gitlab:js:routes`

import { sharedPathHelperTests } from 'jest/lib/utils/path_helpers/shared';

const testCases = [
  {
    pathHelperName: 'identityVerificationExemptionAdminUserPath',
    args: [1, { search: 'foo bar' }],
    baseExpected: '/admin/users/1/identity_verification_exemption?search=foo%20bar',
  },
  {
    pathHelperName: 'adminGeoNodePath',
    args: [1],
    baseExpected: '/admin/geo/sites/1/replication',
  },
];

sharedPathHelperTests({ pathHelpersFilePath: 'ee/lib/utils/path_helpers/admin', testCases });
