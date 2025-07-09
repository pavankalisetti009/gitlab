/* eslint-disable @gitlab/require-i18n-strings */
export const mockSecurityLabelCategories = [
  {
    id: 11,
    name: 'Application',
    description: 'Categorize projects by application type and technology stack.',
    multipleSelection: true,
    canEditCategory: false,
    canEditLabels: true,
    labelCount: 8,
  },
  {
    id: 12,
    name: 'Business Impact',
    description: 'Classify projects by their importance to business operations.',
    multipleSelection: false,
    canEditCategory: false,
    canEditLabels: false,
    labelCount: 5,
  },
  {
    id: 13,
    name: 'Business Unit',
    description: 'Organize projects by owning teams and departments.',
    multipleSelection: true,
    canEditCategory: false,
    canEditLabels: true,
    labelCount: 4,
  },
  {
    id: 14,
    name: 'Exposure level',
    description: 'Tag systems based on network accessibility and exposure risk.',
    multipleSelection: false,
    canEditCategory: false,
    canEditLabels: true,
    labelCount: 4,
  },
  {
    id: 15,
    name: 'Location',
    description: 'Track system hosting locations and geographic deployment.',
    multipleSelection: false,
    canEditCategory: true,
    canEditLabels: true,
    labelCount: 7,
  },
];
export const mockSecurityLabels = [
  {
    id: 1,
    categoryId: 11,
    label: 'Asset Track',
    description:
      'A comprehensive portfolio management system that monitors client investments and tracks asset performance across multiple markets.',
    color: '#3478C6',
  },
  {
    id: 2,
    categoryId: 11,
    label: 'Bank Branch',
    description:
      'A branch operations management platform that streamlines teller workflows, queue management, and daily transaction reconciliation.',
    color: '#67AD5C',
  },
  {
    id: 3,
    categoryId: 11,
    label: 'Capital Commit',
    description:
      'An enterprise lending solution that manages the complete lifecycle of commercial loans from application to disbursement.',
    color: '#EC6337',
  },
  {
    id: 4,
    categoryId: 11,
    label: 'Deposit Source',
    description:
      'A savings account management system that handles interest calculations, automatic transfers, and customer-facing deposit operations.',
    color: '#613CB1',
  },
  {
    id: 5,
    categoryId: 11,
    label: 'Fiscal Flow',
    description:
      'A cash management solution that optimizes liquidity forecasting and treasury operations across the banking network.',
    color: '#4994EC',
  },
  {
    id: 6,
    categoryId: 11,
    label: 'Ledger Link',
    description:
      'A general ledger system that maintains financial records, facilitates account reconciliation, and generates regulatory reports.',
    color: '#F6C444',
  },
  {
    id: 7,
    categoryId: 11,
    label: 'Vault Version',
    description:
      'A secure document management system for handling sensitive financial agreements, contracts, and compliance documentation.',
    color: '#9031AA',
  },
  {
    id: 8,
    categoryId: 11,
    label: 'Wealth Ware',
    description:
      'A private banking platform that provides personalized financial planning tools and investment advisory services for high-net-worth clients.',
    color: '#D63865',
  },
  {
    id: 9,
    categoryId: 12,
    label: 'Mission Critical',
    description: 'Essential for core business functions',
    color: '#A16522',
  },
  {
    id: 10,
    categoryId: 12,
    label: 'Business Critical',
    description: 'Important for key business operations',
    color: '#B8802F',
  },
  {
    id: 11,
    categoryId: 12,
    label: 'Business Operational',
    description: 'Standard operational systems',
    color: '#CF9846',
  },
  {
    id: 12,
    categoryId: 12,
    label: 'Business Administrative',
    description: 'Supporting administrative functions',
    color: '#E2C07F',
  },
  {
    id: 13,
    categoryId: 12,
    label: 'Non-essential',
    description: 'Minimal business impact',
    color: '#F1DAAE',
  },
  {
    id: 14,
    categoryId: 15,
    label: 'Canada::Toronto',
    description: 'Distributed team coordination center for Canadian remote workforce.',
    color: '#9B1EC5',
  },
  {
    id: 15,
    categoryId: 15,
    label: 'Singapore::Singapore',
    description: 'Asia-Pacific regional office covering Southeast Asian operations.',
    color: '#D3875B',
  },
  {
    id: 16,
    categoryId: 15,
    label: 'UK::London',
    description: 'European headquarters serving UK and European markets.',
    color: '#5FC975',
  },
  {
    id: 17,
    categoryId: 15,
    label: 'USA::Austin',
    description:
      'Secondary engineering office focused on backend infrastructure and platform development.',
    color: '#3878C2',
  },
  {
    id: 18,
    categoryId: 15,
    label: 'USA::Denver',
    description: 'Dedicated facility for infrastructure monitoring and cloud services management.',
    color: '#3878C2',
  },
  {
    id: 19,
    categoryId: 15,
    label: 'USA::New York',
    description: 'East Coast sales and business development operations center.',
    color: '#3878C2',
  },
  {
    id: 20,
    categoryId: 15,
    label: 'USA::San Francisco',
    description: 'Primary headquarters and main engineering hub in California.',
    color: '#3878C2',
  },
];

export default {
  Group: {
    securityLabelCategories() {
      return {
        nodes: mockSecurityLabelCategories,
      };
    },
    securityLabels(_, { categoryId }) {
      return {
        nodes: mockSecurityLabels.filter(
          (node) => categoryId === undefined || node.categoryId === categoryId,
        ),
      };
    },
  },
};
