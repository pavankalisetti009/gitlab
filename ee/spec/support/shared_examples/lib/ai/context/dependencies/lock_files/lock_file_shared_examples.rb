# frozen_string_literal: true

# These examples are intended to test Ai::Context::Dependencies::LockFiles::Base child classes.

### Requires a context containing:
#  - lock_file_content: Formatted string content of a valid lock file
#  - expected_formatted_lib_names: Array of library names (and their version in brackets if applicable)
#
### Optionally, the context can contain:
#  - lock_file_class: The lock file class to use instead of `described_class`
#
RSpec.shared_examples 'parsing a valid lock file' do
  let(:blob) { instance_double('Gitlab::Git::Blob', path: 'path/to/lockfile', data: lock_file_content) }
  let(:expected_checksum) { Digest::SHA256.hexdigest(lock_file_content) }
  let(:lock_file) { (try(:lock_file_class) || described_class).new(blob) }

  it 'returns the expected payload' do
    lock_file.parse!

    expect(lock_file).to be_valid
    expect(lock_file.payload).to eq({
      libs: expected_formatted_lib_names.map { |lib_name| { name: lib_name } },
      checksum: expected_checksum,
      fileName: blob.path,
      scannerVersion: described_class::SCANNER_VERSION
    })
  end
end

### Optionally, the context can contain:
#  - invalid_lock_file_content: Content of an invalid lock file
#  - lock_file_class: The lock file class to use instead of `described_class`
#  - expected_parsing_error_message: Message when a parsing error occurs
#
RSpec.shared_examples 'parsing an invalid lock file' do
  let(:lock_file_content) { try(:invalid_lock_file_content) || 'invalid' }
  let(:blob) { instance_double('Gitlab::Git::Blob', path: 'path/to/lockfile', data: lock_file_content) }
  let(:lock_file) { (try(:lock_file_class) || described_class).new(blob) }

  let(:expected_error_message) do
    try(:expected_parsing_error_message) || 'format not recognized or dependencies not present'
  end

  it 'returns an error message' do
    lock_file.parse!

    expect(lock_file).not_to be_valid
    expect(lock_file.error_message).to eq(
      "Error(s) while parsing file `#{blob.path}`: #{expected_error_message}")
    expect(lock_file.payload).to be_nil
  end
end
