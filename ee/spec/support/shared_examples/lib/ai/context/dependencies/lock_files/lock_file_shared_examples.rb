# frozen_string_literal: true

# This is intended to test Ai::Context::Dependencies::LockFiles::Base child classes.
#
### Requires a context containing:
#  - lock_file_content: Formatted string content of a valid lock file
#  - expected_formatted_lib_names: Array of library names (and their version in brackets if applicable)
#
### Optionally, the context can contain:
#  - expected_parsing_error_message: Message when a parsing error occurs
#  - lock_file_class: The lock file class to use instead of `described_class`
#
RSpec.shared_examples 'parsing a lock file' do
  let(:blob) { instance_double('Gitlab::Git::Blob', path: 'path/to/lockfile', data: lock_file_content) }
  let(:expected_checksum) { Digest::SHA256.hexdigest(lock_file_content) }
  let(:default_parsing_error_message) { 'format not recognized or dependencies not present' }
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

  context 'when the lock file content is empty' do
    let(:lock_file_content) { '' }

    it 'returns an error message' do
      lock_file.parse!

      expect(lock_file).not_to be_valid
      expect(lock_file.error_message).to eq("Error(s) while parsing file `#{blob.path}`: file empty")
      expect(lock_file.payload).to be_nil
    end
  end

  context 'when the lock file content format is invalid' do
    let(:lock_file_content) { 'invalid' }
    let(:error_message) { try(:expected_parsing_error_message) || default_parsing_error_message }

    it 'returns an error message' do
      lock_file.parse!

      expect(lock_file).not_to be_valid
      expect(lock_file.error_message).to eq(
        "Error(s) while parsing file `#{blob.path}`: #{error_message}")
      expect(lock_file.payload).to be_nil
    end
  end
end
