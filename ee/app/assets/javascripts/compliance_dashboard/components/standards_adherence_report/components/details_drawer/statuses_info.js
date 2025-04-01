import { __, s__ } from '~/locale';

export const statusesInfo = {
  scanner_sast_running: {
    description: s__(
      'ComplianceStandardsAdherence|Static Application Security Testing (SAST) scans your code for vulnerabilities that may lead to exploits',
    ),
    fixes: [],
  },
  minimum_approvals_required_2: {
    description: s__(
      'ComplianceStandardsAdherence|Enforcing minimum approval requirements ensures code changes are properly reviewed before merging',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure approval requirements'),
        description: s__(
          'ComplianceStandardsAdherence|Configure your project to require at least two approvals on merge requests to improve code quality and security',
        ),
        linkTitle: __('Approval settings'),
        ultimate: false,
        link: 'https://example.com',
      },
      {
        title: s__('ComplianceStandardsAdherence|Learn about code review best practices'),
        description: s__(
          'ComplianceStandardsAdherence|Learn more about implementing effective code review practices to enhance security',
        ),
        linkTitle: __('Best practices'),
        ultimate: false,
        link: 'https://example2.com',
      },
    ],
  },
  merge_request_prevent_author_approval: {
    description: s__(
      'ComplianceStandardsAdherence|Preventing authors from approving their own merge requests ensures independent code review',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Prevent author approvals'),
        description: s__(
          'ComplianceStandardsAdherence|Configure your project settings to prevent merge request authors from approving their own changes',
        ),
        linkTitle: __('Configure approval rules'),
        ultimate: false,
        link: 'https://example.com',
      },
    ],
  },
  merge_request_prevent_committers_approval: {
    description: s__(
      'ComplianceStandardsAdherence|Ensuring that code committers cannot approve their contributed merge requests maintains separation of duties',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Prevent committer approvals'),
        description: s__(
          'ComplianceStandardsAdherence|Update your approval settings to prevent committers from approving merge requests containing their commits',
        ),
        linkTitle: __('Project settings'),
        ultimate: true,
        link: 'https://example.com',
      },
    ],
  },
  project_visibility_not_internal: {
    description: s__(
      'ComplianceStandardsAdherence|Organization policy requires that projects are not set to internal visibility to protect sensitive data',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Update project visibility'),
        description: s__(
          'ComplianceStandardsAdherence|Change your project visibility settings to comply with organizational security requirements',
        ),
        linkTitle: __('Manage visibility'),
        ultimate: false,
        link: 'https://example.com',
      },
    ],
  },
  default_branch_protected: {
    description: s__(
      'ComplianceStandardsAdherence|Default branch protection prevents direct commits and ensures changes are reviewed through merge requests',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Set up branch protection'),
        description: s__(
          'ComplianceStandardsAdherence|Set up branch protection rules for your default branch to enforce quality standards',
        ),
        linkTitle: __('Branch settings'),
        ultimate: false,
        link: 'https://example2.com',
      },
    ],
  },
  auth_sso_enabled: {
    description: s__(
      'ComplianceStandardsAdherence|Single Sign-On authentication improves security by centralizing user access management',
    ),
    fixes: [], // No fixes provided
  },
  scanner_secret_detection_running: {
    description: s__(
      'ComplianceStandardsAdherence|Secret detection prevents sensitive information like API keys from being accidentally committed to your repository',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Implement secret detection'),
        description: s__(
          'ComplianceStandardsAdherence|Implement secret detection scanning in your CI/CD pipeline to identify and remove exposed credentials',
        ),
        linkTitle: __('Implementation guide'),
        ultimate: true,
        link: 'https://example.com',
      },
    ],
  },
  scanner_dep_scanning_running: {
    description: s__(
      'ComplianceStandardsAdherence|Dependency scanning identifies vulnerable dependencies in your project that could be exploited by attackers',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable dependency scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Enable dependency scanning to automatically detect vulnerable libraries in your application',
        ),
        linkTitle: __('Security settings'),
        ultimate: false,
        link: 'https://example.com',
      },
    ],
  },
  scanner_container_scanning_running: {
    description: s__(
      'ComplianceStandardsAdherence|Container scanning checks your container images for known vulnerabilities to prevent exploitation in production',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Set up container scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Set up container scanning in your pipeline to identify vulnerabilities in your container images',
        ),
        linkTitle: __('Configure now'),
        ultimate: true,
        link: 'https://example.com',
      },
      {
        title: s__('ComplianceStandardsAdherence|Review container security practices'),
        description: s__(
          'ComplianceStandardsAdherence|Review best practices for secure container deployments',
        ),
        linkTitle: __('Best practices'),
        ultimate: false,
        link: 'https://example2.com',
      },
    ],
  },
  scanner_license_compliance_running: {
    description: s__(
      'ComplianceStandardsAdherence|License compliance scanning identifies potentially problematic open source licenses that could create legal issues',
    ),
    fixes: [], // No fixes available
  },
  scanner_dast_running: {
    description: s__(
      'ComplianceStandardsAdherence|Dynamic Application Security Testing (DAST) identifies runtime vulnerabilities by analyzing your application while it runs',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Configure DAST scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Configure DAST in your CI/CD pipeline to automatically test your application for security issues',
        ),
        linkTitle: __('Setup guide'),
        ultimate: false,
        link: 'https://example.com',
      },
    ],
  },
  scanner_api_security_running: {
    description: s__(
      'ComplianceStandardsAdherence|API Security testing identifies vulnerabilities specific to your application APIs before they can be exploited',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Implement API security testing'),
        description: s__(
          'ComplianceStandardsAdherence|Implement API security testing to protect your application interfaces from attacks',
        ),
        linkTitle: __('Implementation details'),
        ultimate: true,
        link: 'https://example.com',
      },
    ],
  },
  scanner_fuzz_testing_running: {
    description: s__(
      'ComplianceStandardsAdherence|Fuzz testing automatically generates random inputs to find unexpected behavior and potential security issues',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Set up fuzz testing'),
        description: s__(
          'ComplianceStandardsAdherence|Set up fuzz testing in your pipeline to identify edge cases and potential crashes',
        ),
        linkTitle: __('View tutorial'),
        ultimate: true,
        link: 'https://example.com',
      },
    ],
  },
  scanner_code_quality_running: {
    description: s__(
      'ComplianceStandardsAdherence|Code quality scanning identifies maintainability issues that could lead to increased security risks over time',
    ),
    fixes: [
      {
        title: s__('ComplianceStandardsAdherence|Enable code quality scanning'),
        description: s__(
          'ComplianceStandardsAdherence|Enable code quality scanning to improve code maintainability and reduce technical debt',
        ),
        linkTitle: __('Configuration options'),
        ultimate: false,
        link: 'https://example.com',
      },
    ],
  },
  scanner_iac_running: {
    description: s__(
      'ComplianceStandardsAdherence|Infrastructure as Code (IaC) scanning detects misconfigurations in your infrastructure definitions before deployment',
    ),
    fixes: [], // No fixes provided
  },
};
