# frozen_string_literal: true

module VirtualRegistries
  class Upstream < ApplicationRecord
    self.abstract_class = true

    belongs_to :group

    validates :name, presence: true, length: { maximum: 255 }
    validates :description, length: { maximum: 1024 }
    validates :group, top_level_group: true, presence: true

    validates :url,
      addressable_url: {
        allow_localhost: false,
        allow_local_network: false,
        dns_rebind_protection: true,
        enforce_sanitization: true
      },
      presence: true
    validates :url, length: { maximum: 255 }

    validates :cache_validity_hours, numericality: { greater_than_or_equal_to: 0, only_integer: true }

    after_validation :reset_credentials, if: -> { persisted? && url_changed? }

    scope :eager_load_registry_upstream, ->(registry:) {
      eager_load(:registry_upstreams)
        .where(registry_upstreams: { registry: })
        .order('registry_upstreams.position ASC')
    }

    scope :for_group, ->(group) { where(group:) }
    scope :for_id_and_group, ->(id:, group:) { where(id:, group:) }

    def url_for(path)
      full_url = File.join(url, path)
      Addressable::URI.parse(full_url).to_s
    end

    def object_storage_key
      hash = Digest::SHA2.hexdigest(SecureRandom.uuid)
      Gitlab::HashedPath.new(
        self.class.module_parent_name.underscore,
        group_id,
        'upstream',
        id,
        'cache',
        'entry',
        hash[0..1],
        hash[2..3],
        hash[4..],
        root_hash: group_id
      ).to_s
    end

    def reset_credentials
      return if username_changed? && password_changed?

      self.username = nil
      self.password = nil
    end

    def local?
      false
    end

    def remote?
      true
    end
  end
end
