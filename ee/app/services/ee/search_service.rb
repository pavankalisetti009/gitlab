# frozen_string_literal: true

module EE
  module SearchService
    extend ::Gitlab::Utils::Override

    module ClassMethods
      extend ::Gitlab::Utils::Override

      override :supported_search_types
      def supported_search_types
        super + %w[advanced zoekt]
      end
    end

    def self.prepended(base)
      base.singleton_class.prepend ClassMethods
    end

    # This is a proper method instead of a `delegate` in order to
    # avoid adding unnecessary methods to Search::SnippetService
    def use_elasticsearch?
      search_service.use_elasticsearch?
    end

    def show_epics?
      search_service.allowed_scopes.include?('epics')
    end

    def show_elasticsearch_tabs?
      ::Gitlab::CurrentSettings.search_using_elasticsearch?(scope: search_service.elasticsearchable_scope)
    end

    override :search_type
    def search_type
      search_service.search_type
    end

    def use_zoekt?
      search_service.try(:use_zoekt?)
    end

    override :global_search_enabled_for_scope?
    def global_search_enabled_for_scope?
      case params[:scope]
      when 'blobs'
        ::Gitlab::CurrentSettings.global_search_code_enabled?
      when 'commits'
        ::Gitlab::CurrentSettings.global_search_commits_enabled?
      when 'epics'
        ::Gitlab::CurrentSettings.global_search_epics_enabled?
      when 'wiki_blobs'
        ::Gitlab::CurrentSettings.global_search_wiki_enabled?
      else
        super
      end
    end

    override :search_type_errors
    def search_type_errors
      return if params[:search_type].nil? || params[:search_type] == 'basic'

      errors = []
      case params[:search_type]
      when 'advanced'
        errors << if scope == 'blobs'
                    if !::Gitlab::CurrentSettings.elasticsearch_code_scope
                      "Elasticsearch is disabled for #{scope}"
                    elsif !use_elasticsearch?
                      'Elasticsearch is not available'
                    end
                  end
      when 'zoekt'
        errors << 'Zoekt is not available' unless use_zoekt?
        errors << 'Zoekt can only be used for blobs' unless scope == 'blobs'
      else
        errors << "Search type should be one of these: #{::SearchService.supported_search_types.join(', ')}"
      end
      return if errors.compact.empty?

      errors.join(', ')
    end
  end
end
