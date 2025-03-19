export const MOCK_REPLICABLE_CLASS = {
  graphqlRegistryClass: 'Geo::MockRegistry',
  graphqlFieldName: 'testGraphqlFieldName',
  verificationEnabled: true,
};

export const MOCK_REPLICABLE_WITH_VERIFICATION = {
  id: 'gid://gitlab/Geo::MockRegistry/1',
  checksumMismatch: false,
  createdAt: '2025-01-01',
  lastSyncFailure: null,
  lastSyncedAt: '2025-01-01',
  missingOnPrimary: false,
  modelRecordId: 1,
  retryAt: null,
  retryCount: null,
  state: 'SYNCED',
  verificationChecksum: null,
  verificationChecksumMismatched: false,
  verificationFailure: null,
  verificationRetryAt: null,
  verificationRetryCount: null,
  verificationStartedAt: null,
  verificationState: 'SUCCEEDED',
  verifiedAt: '2025-01-01',
};

export const MOCK_REPLICABLE_WITHOUT_VERIFICATION = {
  id: 'gid://gitlab/Geo::MockRegistry/2',
  checksumMismatch: false,
  createdAt: '2025-01-01',
  lastSyncFailure: null,
  lastSyncedAt: '2025-01-01',
  missingOnPrimary: false,
  modelRecordId: 2,
  retryAt: null,
  retryCount: null,
  state: 'SYNCED',
};
