# frozen_string_literal: true

FactoryBot.define do
  factory :xray_report, class: 'Projects::XrayReport' do
    project
    lang { 'Ruby' }
    payload do
      {
        "file_path" => "pyproject.toml",
        "libs" =>
          [
            {
              "name" => "python ~3.9",
              "description" => "Python is a popular general-purpose programming language used for web development."
            },
            {
              "name" => "uvicorn ^0.20.0",
              "description" => "Uvicorn is a lightning-fast ASGI server implementation for Python."
            }
          ]
      }.to_json
    end
  end
end
