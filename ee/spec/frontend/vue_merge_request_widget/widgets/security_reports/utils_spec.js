import {
  highlightsFromReport,
  transformToEnabledScans,
} from 'ee/vue_merge_request_widget/widgets/security_reports/utils';

describe('MR Widget Security Reports Utils', () => {
  describe('highlightsFromReport', () => {
    it('should compute the highlights properly', () => {
      expect(
        highlightsFromReport({
          full: {
            added: [
              { severity: 'high' },
              { severity: 'high' },
              { severity: 'critical' },
              { severity: 'critical' },
              { severity: 'critical' },
              { severity: 'medium' },
              { severity: 'low' },
              { severity: 'info' },
              { severity: 'unknown' },
            ],
          },
        }),
      ).toEqual({
        critical: 3,
        high: 2,
        other: 4,
      });
    });

    it('should sum full and partial results', () => {
      expect(
        highlightsFromReport({
          full: { added: [{ severity: 'high' }, { severity: 'critical' }, { severity: 'medium' }] },
          partial: { added: [{ severity: 'high' }, { severity: 'critical' }] },
        }),
      ).toEqual({
        critical: 2,
        high: 2,
        other: 1,
      });
    });

    it('should receive an object and modify it', () => {
      const highlights = {
        critical: 1,
        high: 0,
        other: 5,
      };

      expect(
        highlightsFromReport(
          { full: { added: [{ severity: 'high' }, { severity: 'critical' }] } },
          highlights,
        ),
      ).toEqual({
        critical: 2,
        high: 1,
        other: 5,
      });
    });
  });

  describe('transformToEnabledScans', () => {
    it.each`
      scans
      ${{ enabledSecurityScans: { sast: false, dast: false, secretDetection: false } }}
      ${{ enabledSecurityScans: null }}
      ${{ enabledSecurityScans: undefined }}
      ${{}}
    `('should return empty array when no scans enabled: $scans', ({ scans }) => {
      expect(transformToEnabledScans(scans)).toEqual([]);
    });

    it('should ignore unknown scan types', () => {
      const scans = {
        enabledSecurityScans: { sast: true, unknownType: true, anotherUnknown: true },
      };
      expect(transformToEnabledScans(scans)).toEqual([{ reportType: 'SAST', scanMode: 'FULL' }]);
    });

    it('should ignore non-report type fields like "ready"', () => {
      const scans = {
        enabledSecurityScans: {
          ready: true,
          sast: true,
        },
      };
      expect(transformToEnabledScans(scans)).toEqual([{ reportType: 'SAST', scanMode: 'FULL' }]);
    });

    it.each`
      value
      ${'enabled'}
      ${1}
      ${{}}
      ${[]}
    `('should ignore non-boolean value: $value', ({ value }) => {
      const scans = { enabledSecurityScans: { sast: true, dast: value } };
      expect(transformToEnabledScans(scans)).toEqual([{ reportType: 'SAST', scanMode: 'FULL' }]);
    });

    describe('scan modes', () => {
      it('should transform both full and partial scans', () => {
        const scans = {
          enabledSecurityScans: {
            sast: true,
            dast: true,
          },
          enabledPartialSecurityScans: {
            sast: true,
            secretDetection: true,
          },
        };

        const result = transformToEnabledScans(scans);

        expect(result).toEqual([
          { reportType: 'SAST', scanMode: 'FULL' },
          { reportType: 'DAST', scanMode: 'FULL' },
          { reportType: 'SAST', scanMode: 'PARTIAL' },
          { reportType: 'SECRET_DETECTION', scanMode: 'PARTIAL' },
        ]);
      });

      describe.each`
        scanMode     | scanField
        ${'FULL'}    | ${'enabledSecurityScans'}
        ${'PARTIAL'} | ${'enabledPartialSecurityScans'}
      `('$scanMode scans', ({ scanMode, scanField }) => {
        it('should transform multiple enabled security scans', () => {
          const scans = {
            [scanField]: {
              sast: true,
              dast: false,
              secretDetection: true,
            },
          };

          const result = transformToEnabledScans(scans);

          expect(result).toEqual([
            { reportType: 'SAST', scanMode },
            { reportType: 'SECRET_DETECTION', scanMode },
          ]);
        });

        it.each`
          scanType                  | expectedReportType
          ${'sast'}                 | ${'SAST'}
          ${'dast'}                 | ${'DAST'}
          ${'secretDetection'}      | ${'SECRET_DETECTION'}
          ${'apiFuzzing'}           | ${'API_FUZZING'}
          ${'coverageFuzzing'}      | ${'COVERAGE_FUZZING'}
          ${'dependencyScanning'}   | ${'DEPENDENCY_SCANNING'}
          ${'containerScanning'}    | ${'CONTAINER_SCANNING'}
          ${'clusterImageScanning'} | ${'CLUSTER_IMAGE_SCANNING'}
        `(
          'should transform $scanType to $expectedReportType',
          ({ scanType, expectedReportType }) => {
            const scans = { [scanField]: { [scanType]: true } };

            expect(transformToEnabledScans(scans)).toEqual([
              { reportType: expectedReportType, scanMode },
            ]);
          },
        );
      });
    });
  });
});
