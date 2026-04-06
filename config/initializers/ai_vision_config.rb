# typed: strict

# Configuration for AI Vision (Ollama)
OLLAMA_URL = ENV.fetch('OLLAMA_URL', 'http://ollama:11434')
OLLAMA_MODEL = ENV.fetch('OLLAMA_MODEL', 'moondream')
