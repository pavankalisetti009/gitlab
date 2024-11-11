# frozen_string_literal: true

RSpec.describe Gitlab::Backup::Cli::Shell::Command do
  let(:envdata) do
    { 'CUSTOM' => 'data' }
  end

  subject(:command) { described_class }

  describe '#initialize' do
    it 'accepts required attributes' do
      expect { command.new('ls', '-l') }.not_to raise_exception
    end

    it 'accepts optional attributes' do
      expect { command.new('ls', '-l', env: envdata) }.not_to raise_exception
    end
  end

  describe '#cmd_args' do
    let(:cmd_args) { %w[ls -l] }

    it 'returns a list of command args' do
      cmd = command.new(*cmd_args)

      expect(cmd.cmd_args).to eq(cmd_args)
    end

    context 'when with_env is true' do
      it 'returns the same list of command args when no env is provided' do
        cmd = command.new(*cmd_args)

        expect(cmd.cmd_args(with_env: true)).to eq(cmd_args)
      end

      it 'returns a list of command args with the env hash as its first element' do
        cmd = command.new(*cmd_args, env: envdata)

        result = cmd.cmd_args(with_env: true)

        expect(result.first).to eq(envdata)
        expect(result[1..]).to eq(cmd_args)
      end
    end
  end

  describe '#capture' do
    it 'returns stdout from executed command' do
      expected_output = 'my custom content'

      result = command.new('echo', expected_output).capture

      expect(result.stdout.chomp).to eq(expected_output)
      expect(result.stderr).to be_empty
    end

    it 'returns stderr from executed command' do
      expected_output = 'my custom error content'

      result = command.new('sh', '-c', "echo #{expected_output} > /dev/stderr").capture

      expect(result.stdout).to be_empty
      expect(result.stderr.chomp).to eq(expected_output)
    end

    it 'returns a Process::Status from the executed command' do
      result = command.new('pwd').capture

      expect(result.status).to be_a(Process::Status)
      expect(result.status).to respond_to(:exited?, :termsig, :stopsig, :exitstatus, :success?, :pid)
    end

    it 'returns the execution duration' do
      result = command.new('sleep 0.1').capture

      expect(result.duration).to be > 0.1
    end

    it 'sets the provided env variables as part of process execution' do
      result = command.new("echo \"variable value ${CUSTOM}\"", env: envdata).capture

      expect(result.stdout.chomp).to eq('variable value data')
    end
  end
end
