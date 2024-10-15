import { GlButton } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import { componentNames, iconComponentNames } from 'ee/ci/reports/components/issue_body';
import { codequalityParsedIssues } from 'ee_jest/vue_merge_request_widget/mock_data';
import LicenseIssueBody from 'ee/vue_shared/license_compliance/components/license_issue_body.vue';
import LicenseStatusIcon from 'ee/vue_shared/license_compliance/components/license_status_icon.vue';
import SecurityIssueBody from 'ee/vue_shared/security_reports/components/security_issue_body.vue';
import CodequalityIssueBody from '~/ci/reports/codequality_report/components/codequality_issue_body.vue';
import ModalOpenName from 'ee/ci/reports/components/modal_open_name.vue';
import SeverityBadge from 'ee/vue_shared/security_reports/components/severity_badge.vue';
import ReportLink from '~/ci/reports/components/report_link.vue';
import {
  sastParsedIssues,
  dockerReportParsed,
  parsedDast,
  secretDetectionParsedIssues,
  licenseComplianceParsedIssues,
} from 'ee_jest/vue_shared/security_reports/mock_data';
import ReportIssue from '~/ci/reports/components/report_item.vue';
import { STATUS_FAILED, STATUS_SUCCESS, STATUS_NEUTRAL } from '~/ci/reports/constants';

describe('Report issue', () => {
  let wrapper;

  describe('for codequality issue', () => {
    describe('resolved issue', () => {
      beforeEach(() => {
        wrapper = shallowMount(ReportIssue, {
          propsData: {
            issue: codequalityParsedIssues[0],
            component: componentNames.CodequalityIssueBody,
            status: STATUS_SUCCESS,
          },
          stubs: {
            CodequalityIssueBody,
            ReportLink,
          },
        });
      });

      it('should render "Fixed" keyword', () => {
        expect(wrapper.text()).toContain('Fixed');
        expect(wrapper.text()).toMatchInterpolatedText(
          'Fixed: Minor - Insecure Dependency in Gemfile.lock:12',
        );
      });
    });

    describe('unresolved issue', () => {
      beforeEach(() => {
        wrapper = shallowMount(ReportIssue, {
          propsData: {
            issue: codequalityParsedIssues[0],
            component: componentNames.CodequalityIssueBody,
            status: STATUS_FAILED,
          },
        });
      });

      it('should not render "Fixed" keyword', () => {
        expect(wrapper.text()).not.toContain('Fixed');
      });
    });
  });

  describe('with location', () => {
    it('should render location', () => {
      wrapper = mount(ReportIssue, {
        propsData: {
          issue: sastParsedIssues[0],
          component: componentNames.SecurityIssueBody,
          status: STATUS_FAILED,
        },
        stubs: {
          SecurityIssueBody,
        },
      });

      expect(wrapper.text()).toContain('in');
      expect(wrapper.find('li a').attributes('href')).toEqual(sastParsedIssues[0].urlPath);
    });
  });

  describe('without location', () => {
    it('should not render location', () => {
      wrapper = mount(ReportIssue, {
        propsData: {
          issue: {
            title: 'foo',
          },
          component: componentNames.SecurityIssueBody,
          status: STATUS_SUCCESS,
        },
        stubs: {
          SecurityIssueBody,
        },
      });

      expect(wrapper.text()).not.toContain('in');
      expect(wrapper.find('a').exists()).toBe(false);
    });
  });

  describe('for container scanning issue', () => {
    beforeEach(() => {
      wrapper = shallowMount(ReportIssue, {
        propsData: {
          issue: dockerReportParsed.unapproved[0],
          component: componentNames.SecurityIssueBody,
          status: STATUS_FAILED,
        },
        stubs: {
          SecurityIssueBody,
          SeverityBadge,
          ModalOpenName,
        },
      });
    });

    it('renders severity', () => {
      expect(wrapper.text().toLowerCase()).toContain(dockerReportParsed.unapproved[0].severity);
    });

    it('renders CVE name', () => {
      expect(wrapper.findComponent(GlButton).text()).toEqual(
        dockerReportParsed.unapproved[0].title,
      );
    });
  });

  describe('for dast issue', () => {
    beforeEach(() => {
      wrapper = shallowMount(ReportIssue, {
        propsData: {
          issue: parsedDast[0],
          component: componentNames.SecurityIssueBody,
          status: STATUS_FAILED,
        },
        stubs: {
          SecurityIssueBody,
          SeverityBadge,
          ModalOpenName,
        },
      });
    });

    it('renders severity and title', () => {
      expect(wrapper.text()).toContain(parsedDast[0].title);
      expect(wrapper.text().toLowerCase()).toContain(`${parsedDast[0].severity}`);
    });
  });

  describe('for secret Description issue', () => {
    beforeEach(() => {
      wrapper = shallowMount(ReportIssue, {
        propsData: {
          issue: secretDetectionParsedIssues[0],
          component: componentNames.SecurityIssueBody,
          status: STATUS_FAILED,
        },
        stubs: {
          SecurityIssueBody,
          SeverityBadge,
          ModalOpenName,
        },
      });
    });

    it('renders severity', () => {
      expect(wrapper.text().toLowerCase()).toContain(secretDetectionParsedIssues[0].severity);
    });

    it('renders CVE name', () => {
      expect(wrapper.findComponent(GlButton).text()).toEqual(secretDetectionParsedIssues[0].title);
    });
  });

  describe('for license compliance issue', () => {
    it('renders LicenseIssueBody & LicenseStatusIcon', () => {
      wrapper = shallowMount(ReportIssue, {
        propsData: {
          issue: licenseComplianceParsedIssues[0],
          component: componentNames.LicenseIssueBody,
          iconComponent: iconComponentNames.LicenseStatusIcon,
          status: STATUS_NEUTRAL,
        },
        stubs: {
          LicenseIssueBody,
          LicenseStatusIcon,
        },
      });

      expect(wrapper.findComponent(LicenseIssueBody).exists()).toBe(true);
      expect(wrapper.findComponent(LicenseStatusIcon).exists()).toBe(true);
    });
  });

  describe('showReportSectionStatusIcon', () => {
    it('does not render CI Status Icon when showReportSectionStatusIcon is false', () => {
      wrapper = mount(ReportIssue, {
        propsData: {
          issue: parsedDast[0],
          component: componentNames.SecurityIssueBody,
          status: STATUS_SUCCESS,
          showReportSectionStatusIcon: false,
        },
      });

      expect(wrapper.findAll('.report-block-list-icon')).toHaveLength(0);
    });

    it('shows status icon when unspecified', () => {
      wrapper = mount(ReportIssue, {
        propsData: {
          issue: parsedDast[0],
          component: componentNames.SecurityIssueBody,
          status: STATUS_SUCCESS,
        },
      });

      expect(wrapper.findAll('.report-block-list-icon')).toHaveLength(1);
    });
  });
});
