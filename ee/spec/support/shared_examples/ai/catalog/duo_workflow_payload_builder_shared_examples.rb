# frozen_string_literal: true

RSpec.shared_examples 'builds valid flow configuration' do
  it 'returns correct flow configuration structure' do
    expect(result).to include(
      'version' => 'experimental',
      'environment' => 'remote',
      'components' => be_an(Array),
      'routers' => be_an(Array),
      'flow' => be_a(Hash)
    )
  end

  it 'builds components with correct structure' do
    expect(result['components']).to all(include(
      'name' => be_a(String),
      'type' => 'AgentComponent',
      'prompt_id' => 'workflow_catalog',
      'prompt_version' => '^1.0.0',
      'inputs' => be_an(Array),
      'output' => 'context:agent.answer',
      'toolset' => be_an(Array)
    ))
  end
end

RSpec.shared_examples 'invalid flow configuration' do
  it 'raises error during build' do
    expect { builder.build }.to raise_error(StandardError)
  end
end
