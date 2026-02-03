# frozen_string_literal: true

module EE
  module TestEnv
    extend ::Gitlab::Utils::Override

    EE_SETUP_METHODS = %i[setup_gitlab_ai_gateway].freeze
    GITLAB_AI_GATEWAY_TEST_DIR = 'gitlab-ai-gateway'

    override :setup_methods
    def setup_methods
      EE_SETUP_METHODS + super
    end

    override :setup_go_projects
    def setup_go_projects
      super

      setup_indexer
      setup_openbao
      setup_zoekt
    end

    override :post_init
    def post_init
      super

      Settings.elasticsearch['indexer_path'] = indexer_bin_path
      Settings.zoekt['bin_path'] = zoekt_bin_path
    end

    def setup_indexer
      component_timed_setup(
        'GitLab Elasticsearch Indexer',
        install_dir: indexer_path,
        version: indexer_version,
        task: "gitlab:indexer:install",
        task_args: [indexer_path, indexer_url].compact
      )
    end

    def setup_zoekt
      component_timed_setup(
        'GitLab Zoekt',
        install_dir: zoekt_path,
        version: zoekt_version,
        task: "gitlab:zoekt:install",
        task_args: [zoekt_path, zoekt_url].compact
      )
    end

    def setup_openbao
      component_timed_setup(
        'OpenBao',
        install_dir: SecretsManagement::OpenbaoTestSetup.install_dir,
        version: SecretsManagement::SecretsManagerClient.expected_server_version,
        task: "gitlab:secrets_management:openbao:download_or_clone",
        task_args: [SecretsManagement::OpenbaoTestSetup.install_dir]
      ) do
        raise ::TestEnv::ComponentFailedToInstallError unless SecretsManagement::OpenbaoTestSetup.build_openbao_binary
      end
    end

    def setup_gitlab_ai_gateway
      return unless ::Tasks::Gitlab::AiGateway::Utils.duo_workflow_service_enabled?

      component_timed_setup(
        'GitLab AI Gateway',
        install_dir: ai_gateway_path,
        version: ::Tasks::Gitlab::AiGateway::Utils.latest_sha,
        task: "gitlab:ai_gateway:install",
        task_args: [ai_gateway_path].compact
      )
    end

    def indexer_path
      @indexer_path ||= File.join('tmp', 'tests', 'gitlab-elasticsearch-indexer')
    end

    def indexer_bin_path
      @indexer_bin_path ||= File.join(indexer_path, 'bin', 'gitlab-elasticsearch-indexer')
    end

    def indexer_version
      @indexer_version ||= ::Gitlab::Elastic::Indexer.indexer_version
    end

    def indexer_url
      ENV.fetch('GITLAB_ELASTICSEARCH_INDEXER_URL', nil)
    end

    def zoekt_path
      @zoekt_path ||= File.join('tmp', 'tests', 'gitlab-zoekt')
    end

    def zoekt_bin_path
      @zoekt_bin_path ||= File.join(zoekt_path, 'bin', 'gitlab-zoekt')
    end

    def zoekt_url
      ENV.fetch('GITLAB_ZOEKT_URL', nil)
    end

    def zoekt_version
      @zoekt_version ||= Rails.root.join('GITLAB_ZOEKT_VERSION').read.chomp
    end

    def ai_gateway_path
      @ai_gateway_path ||= File.join('tmp', 'tests', GITLAB_AI_GATEWAY_TEST_DIR)
    end

    def with_duo_workflow_service
      pid = ::Tasks::Gitlab::AiGateway::Utils.run_duo_workflow_service(path: ai_gateway_path)

      yield
    ensure
      Process.kill('TERM', pid) if pid
      Process.wait(pid) if pid
    end

    private

    def test_dirs
      @ee_test_dirs ||= super + %W[
        gitlab-elasticsearch-indexer
        gitlab-zoekt
        openbao
        #{GITLAB_AI_GATEWAY_TEST_DIR}
        #{File.basename(::Search::Zoekt::ZoektProcessManager::INDEX_DIR)}
        #{File.basename(::Search::Zoekt::ZoektProcessManager::LOG_DIR)}
      ]
    end
  end
end
