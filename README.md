# Anoma Local Domain

**Anoma Local Domain**
The Anoma Local Domain is an operating system that acts as a trust-zone for anoma-derived data & applications.

Each Anoma controller requires immediate global consensus, but the local domain can work as a private sandbox and hold non-consensus state.

It contains applications for interacting with various external controllers.

## Installation

```elixir
def deps do
  [
    {:anoma_local_domain, git: "https://github.com/anoma/anoma-local-domain", branch: "jam/norocks"}
  ]
end
```
