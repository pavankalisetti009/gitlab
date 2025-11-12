# frozen_string_literal: true

scope 'v2/virtual_registries/container/:id/*image', format: false do
  constraints(
    image: ::Gitlab::PathRegex.container_image_regex,
    tag_or_digest: ::Gitlab::PathRegex.oci_tag_or_digest_regex,
    sha: ::Gitlab::PathRegex.oci_blob_digest_regex
  ) do
    get 'manifests/*tag_or_digest',
      to: 'virtual_registries/container#manifest',
      as: :virtual_registries_container_manifest

    get 'blobs/:sha',
      to: 'virtual_registries/container#blob',
      as: :virtual_registries_container_blob
  end
end
