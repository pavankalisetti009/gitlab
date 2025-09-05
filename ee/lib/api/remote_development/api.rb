# frozen_string_literal: true

module API
  module RemoteDevelopment
    class API < ::API::Base
      mount ::API::RemoteDevelopment::Internal::Agents::Agentw::ServerConfig
      mount ::API::RemoteDevelopment::Internal::Agents::Agentw::AgentInfo
    end
  end
end
