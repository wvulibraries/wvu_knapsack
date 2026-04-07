# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'
require 'base64'

RSpec.describe VisionService do
  let(:ollama_url) { 'http://ollama:11434/api/generate' }
  let(:image_bytes) { 'fake-image-bytes' }
  let(:base64_image) { Base64.strict_encode64(image_bytes) }
  let(:context_id) { 'test-fileset-001' }
  let(:raw_alt_text) { 'A photograph of a river valley in West Virginia.' }
  let(:ollama_response) { { 'response' => raw_alt_text }.to_json }

  before do
    stub_request(:post, ollama_url)
      .with(
        body: hash_including(
          'model'  => VisionService::OLLAMA_MODEL,
          'prompt' => VisionService::PROMPT,
          'images' => [base64_image],
          'stream' => false
        )
      )
      .to_return(status: 200, body: ollama_response, headers: { 'Content-Type' => 'application/json' })
  end

  describe '.call_with_bytes' do
    it 'returns sanitized alt text from Ollama' do
      result = described_class.call_with_bytes(image_bytes, context_id)
      expect(result).to be_a(String)
      expect(result.length).to be <= 125
    end

    context 'when Ollama returns an empty response' do
      let(:ollama_response) { { 'response' => '' }.to_json }

      it 'returns nil' do
        result = described_class.call_with_bytes(image_bytes, context_id)
        expect(result).to be_nil
      end
    end

    context 'when Ollama times out' do
      before do
        stub_request(:post, ollama_url).to_timeout
      end

      it 'returns nil and logs the failure' do
        expect(Rails.logger).to receive(:tagged).with('AI_REMEDIATION_FAILURE').and_yield
        expect(Rails.logger).to receive(:error).with(/TimeoutError/)
        result = described_class.call_with_bytes(image_bytes, context_id)
        expect(result).to be_nil
      end
    end

    context 'when Ollama returns malformed JSON' do
      before do
        stub_request(:post, ollama_url).to_return(status: 200, body: 'not json')
      end

      it 'returns nil' do
        result = described_class.call_with_bytes(image_bytes, context_id)
        expect(result).to be_nil
      end
    end
  end

  describe '.call' do
    let(:file_set) { instance_double('FileSet', id: context_id, mime_type: 'image/jpeg') }
    let(:original_file) { instance_double('Hydra::PCDM::File', content: image_bytes) }

    before do
      allow(file_set).to receive(:original_file).and_return(original_file)
    end

    it 'delegates to call_with_bytes for supported MIME types' do
      result = described_class.call(file_set)
      expect(result).to be_a(String)
    end

    context 'with an unsupported MIME type' do
      let(:file_set) { instance_double('FileSet', id: context_id, mime_type: 'application/pdf') }

      it 'returns nil and logs a warning' do
        expect(Rails.logger).to receive(:warn).with(/Unsupported MIME/)
        result = described_class.call(file_set)
        expect(result).to be_nil
      end
    end

    context 'when original_file has no content' do
      let(:original_file) { instance_double('Hydra::PCDM::File', content: nil) }

      it 'returns nil and logs a warning' do
        expect(Rails.logger).to receive(:warn).with(/No original file content/)
        result = described_class.call(file_set)
        expect(result).to be_nil
      end
    end
  end
end
