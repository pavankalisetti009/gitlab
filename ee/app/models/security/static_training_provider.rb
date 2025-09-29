# frozen_string_literal: true

module Security
  class StaticTrainingProvider
    include ActiveRecord::FixedItemsModel::Model

    ITEMS = [
      {
        id: 1,
        name: "Kontra",
        description: "Kontra Application Security provides interactive developer security education that enables \
        engineers to quickly learn security best practices and fix issues in their code by analysing real-world \
        software security vulnerabilities.",
        url: "https://application.security/api/webhook/gitlab/exercises/search",
        logo_url: nil
      },
      {
        id: 2,
        name: "Secure Code Warrior",
        description: "Resolve vulnerabilities faster and confidently with highly relevant and bite-sized secure \
        coding learning.",
        url: "https://integration-api.securecodewarrior.com/api/v1/trial",
        logo_url: nil
      },
      {
        id: 3,
        name: "SecureFlag",
        description: "Get remediation advice with example code and recommended hands-on labs in a fully \
        interactive virtualized environment.",
        url: "https://knowledge-base-api.secureflag.com/gitlab",
        logo_url: nil
      }
    ].freeze

    attribute :id, :integer
    attribute :name, :string
    attribute :description, :string
    attribute :url, :string
    attribute :logo_url, :string
  end
end
