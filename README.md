# NB2Lite Agent

NB2Lite Agent is a Python/FastMCP server that exposes Gemini image generation and editing as MCP tools. It wraps the Google GenAI SDK Interactions API for `gemini-3.1-flash-lite-image`, saves returned images locally, and returns the interaction IDs needed for multi-turn edits.

The current project is intentionally small:

- `server.py` defines the FastMCP server and tool implementations.
- `test_agent.py` contains mocked unit tests for helper logic and tool behavior.
- `set_env.sh` configures local Gemini credentials and updates legacy Kiro MCP settings when present.
- `.codex/config.toml` contains a Codex MCP server entry for this repo.

## Features

- Text-to-image generation through `generate_image`.
- Stateful image edits through `edit_image` using a previous interaction ID.
- Local image editing through `edit_local_image`, with local images encoded as inline base64 input.
- Runtime help through `get_help`.
- Configurable model name, output directory, aspect ratio, and thinking level.
- Concurrent-safe file names using timestamp plus UUID suffixes.

## Requirements

- Python 3.10 or newer.
- A Gemini API key available as `GEMINI_API_KEY` or `GOOGLE_API_KEY`.
- Python packages from [requirements.txt](/Users/xbill/nb2lite-codex/requirements.txt):
  - `google-genai`
  - `mcp`

Install dependencies:

```bash
make install
```

or:

```bash
pip install -r requirements.txt
```

## Configuration

The server reads these environment variables:

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `GEMINI_API_KEY` | Yes, unless `GOOGLE_API_KEY` is set | None | Primary Gemini API key. |
| `GOOGLE_API_KEY` | Fallback | None | Used when `GEMINI_API_KEY` is not set. |
| `GEMINI_MODEL_NAME` | No | `gemini-3.1-flash-lite-image` | Overrides the model passed to the Interactions API. |
| `IMAGE_OUTPUT_DIR` | No | `.` | Directory where generated and edited images are saved. |

Use the helper script to export credentials for the current shell and write a local `.env` file:

```bash
source set_env.sh
```

`set_env.sh` reads `~/gemini.key` when it exists. Otherwise it prompts for a key, writes it to `~/gemini.key`, sets the file mode to `600`, exports both `GEMINI_API_KEY` and `GOOGLE_API_KEY`, and updates `.kiro/settings/mcp.json` if that legacy config exists.

## Running

Start the MCP server directly:

```bash
make run
```

or:

```bash
python server.py
```

For MCP development tooling:

```bash
mcp dev server.py
```

## Codex MCP Configuration

This repo includes [.codex/config.toml](/Users/xbill/nb2lite-codex/.codex/config.toml), which registers `nb2lite-agent` as a local MCP server:

```toml
[mcp_servers.nb2lite-agent]
command = "/opt/homebrew/bin/python3"
args = ["/Users/xbill/nb2lite-codex/server.py"]
enabled = true
env_vars = ["GEMINI_API_KEY", "GOOGLE_API_KEY"]
```

If your Python path or checkout path differs, update `command` and `args` accordingly.

## MCP Tools

### `generate_image`

Generates a new image from a text prompt and saves it locally.

Arguments:

- `prompt` (`str`, required): Natural language image description.
- `aspect_ratio` (`str`, optional): `1:1`, `16:9`, `9:16`, `4:3`, or `3:4`. Default: `1:1`.
- `thinking_level` (`str`, optional): `minimal`, `low`, `medium`, or `high`. Default: `medium`.

Example:

```python
generate_image(
    prompt="A compact workstation overlooking a rainy neon city",
    aspect_ratio="16:9",
    thinking_level="high",
)
```

### `edit_image`

Edits an image from a previous interaction while preserving state through `previous_interaction_id`.

Arguments:

- `previous_interaction_id` (`str`, required): Interaction ID from a previous generation or edit.
- `edit_prompt` (`str`, required): Natural language edit instruction.
- `thinking_level` (`str`, optional): `minimal`, `low`, `medium`, or `high`. Default: `medium`.

Example:

```python
edit_image(
    previous_interaction_id="int_abc123",
    edit_prompt="Change the city lights to warm amber and add light fog",
    thinking_level="medium",
)
```

### `edit_local_image`

Uploads a local image as base64 input and applies a prompt-based edit.

Arguments:

- `image_path` (`str`, required): Relative or absolute path to a local image.
- `edit_prompt` (`str`, required): Natural language edit instruction.
- `aspect_ratio` (`str`, optional): `1:1`, `16:9`, `9:16`, `4:3`, or `3:4`. Default: `1:1`.
- `thinking_level` (`str`, optional): `minimal`, `low`, `medium`, or `high`. Default: `medium`.

Example:

```python
edit_local_image(
    image_path="./reference.png",
    edit_prompt="Keep the composition but render it as a polished product mockup",
    aspect_ratio="4:3",
)
```

### `get_help`

Returns server help text, current configuration status, available tools, and output file behavior.

## Output Files

Successful image responses are written to `IMAGE_OUTPUT_DIR` using this pattern:

```text
<prefix>_<timestamp>_<uuid_hex>.<extension>
```

Prefixes are:

- `gen` for `generate_image`
- `edit` for `edit_image`
- `edit_local` for `edit_local_image`

The extension is inferred from the returned image MIME type. JPEG is used as the fallback.

## Development

Common commands:

| Command | Description |
| --- | --- |
| `make install` | Install runtime dependencies. |
| `make run` | Start the MCP server. |
| `make test` | Run the mocked unit test suite. |
| `make lint` | Run `ruff check`, `ruff format --check`, and `mypy`. |
| `make clean` | Remove Python and tooling caches. |

Run tests:

```bash
make test
```

The tests mock Gemini API responses; they do not require network access or a real API key for the covered cases.

## Related Documentation

- [GEMINI.md](/Users/xbill/nb2lite-codex/GEMINI.md) explains how the project maps Gemini Interactions API concepts to the MCP tools.
