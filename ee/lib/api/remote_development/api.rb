# frozen_string_literal: true

module API
  module RemoteDevelopment
    class API < ::API::Base
      mount ::API::RemoteDevelopment::Internal::Agent::Agentw
    end
  end
end
