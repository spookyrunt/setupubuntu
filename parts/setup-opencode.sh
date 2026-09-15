#!/bin/bash
set -euo pipefail

curl -fsSL https://opencode.ai/install | bash

jq '
  .provider = ((.provider // {}) + {
    "llama.cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "local-llm": {
          "name": "Local LLM"
        }
      }
    }
  })
  |
  .permission = ((.permission // {}) + {
    "read": "allow",
    "edit": "ask",
    "bash": "ask",
    "glob": "allow",
    "grep": "allow",
    "task": "ask",
    "skill": "ask",
    "lsp": "allow",
    "question": "allow",
    "webfetch": "ask",
    "websearch": "ask",
    "external_directory": "ask",
    "doom_loop": "ask"
  })
' ~/.config/opencode/opencode.json >"/tmp/opencode.json.$$" &&
  mv "/tmp/opencode.json.$$" ~/.config/opencode/opencode.json
