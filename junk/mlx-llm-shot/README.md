# MLX LLM Swift CLI

A Swift command-line interface for interacting with locally running MLX LLM servers.

## Prerequisites

- macOS 13.0 or later
- Swift 5.9 or later
- A locally running MLX LLM server (see setup below)

## Setting Up MLX LLM Server

First, you need to run an MLX LLM server locally. Here's how to set one up:

### Option 1: Using mlx-lm (Recommended)

```bash
# Install mlx-lm
pip install mlx-lm

# Run a server with a model (e.g., Mistral 7B)
mlx_lm.server --model mlx-community/Mistral-7B-Instruct-v0.3-4bit

# Or with a specific port
mlx_lm.server --model mlx-community/Mistral-7B-Instruct-v0.3-4bit --port 8080
```

### Option 2: Using mlx-lm with Python script

```python
from mlx_lm import load, generate
from flask import Flask, request, jsonify

app = Flask(__name__)
model, tokenizer = load("mlx-community/Mistral-7B-Instruct-v0.3-4bit")

@app.route('/v1/completions', methods=['POST'])
def completions():
    data = request.json
    prompt = data.get('prompt', '')
    max_tokens = data.get('max_tokens', 512)
    temperature = data.get('temperature', 0.7)

    response = generate(model, tokenizer, prompt=prompt,
                       max_tokens=max_tokens, temp=temperature)

    return jsonify({
        'choices': [{'text': response}]
    })

if __name__ == '__main__':
    app.run(port=8080)
```

## Building the CLI

```bash
# Clone or navigate to the project directory
cd mlx-llm-shot

# Build the project
swift build

# Or build for release (optimized)
swift build -c release
```

## Usage

### Basic usage

```bash
# Run in debug mode
swift run mlx-llm-cli --prompt "What is the capital of France?"

# Or use the built binary
.build/debug/mlx-llm-cli --prompt "What is the capital of France?"

# Release build
.build/release/mlx-llm-cli --prompt "What is the capital of France?"
```

### With custom options

```bash
# Custom server URL and endpoint
swift run mlx-llm-cli \
  --prompt "Explain quantum computing in simple terms" \
  --url "http://localhost:8080" \
  --endpoint "/v1/completions"

# Custom generation parameters
swift run mlx-llm-cli \
  --prompt "Write a haiku about coding" \
  --max-tokens 100 \
  --temperature 0.9
```

### Command-line options

- `-p, --prompt <text>`: The prompt to send to the LLM (required)
- `-u, --url <url>`: Server URL (default: `http://localhost:8080`)
- `-e, --endpoint <path>`: API endpoint path (default: `/v1/completions`)
- `-m, --max-tokens <number>`: Maximum tokens to generate (default: 512)
- `-t, --temperature <number>`: Temperature for sampling (default: 0.7)

### Examples

```bash
# Simple question
swift run mlx-llm-cli -p "What is machine learning?"

# Creative writing with higher temperature
swift run mlx-llm-cli -p "Write a short story about a robot" -t 0.95 -m 1000

# Technical explanation with lower temperature
swift run mlx-llm-cli -p "Explain how neural networks work" -t 0.3 -m 500
```

## Installing as a System Command

To install the CLI as a system-wide command:

```bash
# Build in release mode
swift build -c release

# Copy to /usr/local/bin (or any directory in your PATH)
sudo cp .build/release/mlx-llm-cli /usr/local/bin/

# Now you can use it from anywhere
mlx-llm-cli -p "Hello, MLX!"
```

## Troubleshooting

### Connection refused

If you get a connection error, make sure your MLX server is running:

```bash
# Check if something is running on port 8080
lsof -i :8080

# Or try with curl
curl -X POST http://localhost:8080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"prompt": "test", "max_tokens": 10}'
```

### Invalid response format

Different MLX servers may return responses in different formats. The CLI tries to handle multiple formats, but if you encounter issues, check your server's response format and modify the parsing logic in `Sources/main.swift`.

## API Compatibility

This CLI is designed to work with OpenAI-compatible API endpoints. It sends requests in the following format:

```json
{
  "prompt": "Your prompt here",
  "max_tokens": 512,
  "temperature": 0.7,
  "stream": false
}
```

And expects responses like:

```json
{
  "choices": [
    {
      "text": "Generated response here"
    }
  ]
}
```

## License

MIT
