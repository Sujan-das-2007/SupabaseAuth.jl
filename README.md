# SupabaseAuth.jl ⚡

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Build Status](https://github.com/USERNAME/SupabaseAuth.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/USERNAME/SupabaseAuth.jl/actions) [![Julia](https://img.shields.io/badge/julia-v1.6+-9558B2.svg)](https://julialang.org)

**SupabaseAuth.jl** — A modern, production-ready Authentication SDK for Supabase in Julia.

Quick links: [Documentation](#) · [Changelog](CHANGELOG.md) · [Issues](https://github.com/USERNAME/SupabaseAuth.jl/issues)

---

***Explanation: polished README with clear headings, copyable examples, and links to source/docs.***

# SupabaseAuth.jl — modern Supabase auth for Julia ⚡

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Build Status](https://github.com/USERNAME/SupabaseAuth.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/USERNAME/SupabaseAuth.jl/actions) [![Julia](https://img.shields.io/badge/julia-v1.6+-9558B2.svg)](https://julialang.org)

SupabaseAuth.jl is a focused, resilient Authentication SDK for Supabase written in Julia. It provides safe session handling, automatic token refresh, helpful macros for background tasks and profiling, and small, ergonomic helpers for authenticated HTTP requests.

Table of contents

- [Quick links](#quick-links)
- [Install](#install)
- [Quick start](#quick-start)
- [Examples (copyable)](#examples-copyable)
- [API reference](#api-reference)
- [Configuration & best practices](#configuration--best-practices)
- [Contributing](#contributing)
- [License & security](#license--security)

---

## Quick links

- Documentation: (coming soon)
- Source: [src/SupabaseAuth.jl](src/SupabaseAuth.jl)
- Issues: https://github.com/USERNAME/SupabaseAuth.jl/issues

---

## Install

If registered:

```julia
using Pkg
Pkg.add("SupabaseAuth")
```

From GitHub (development):

```julia
using Pkg
Pkg.add(url = "https://github.com/USERNAME/SupabaseAuth.jl")
```

Then:

```julia
using SupabaseAuth
```

> All examples are in fenced code blocks; GitHub shows a one-click copy icon on these blocks.

---

## Quick start

Copy this minimal example and run it in a Julia REPL or script.

```julia
using SupabaseAuth

# 1. Create client
client = SupabaseClient("https://your-project.supabase.co", "your-anon-key")

# 2. Login
session = login(client, "user@example.com", "password123")

# 3. Start auto-refresh
start_auto_refresh(client, session)

# 4. Make an authenticated request
todos = request(client, session, "GET", "/rest/v1/todos?select=*")
println("Fetched ", length(todos), " todos")

# 5. Sign out
sign_out(client, session)
```

---

## Examples (copyable)

### Sign up with metadata

```julia
using SupabaseAuth

client = SupabaseClient("https://your-project.supabase.co", "your-anon-key")
res = sign_up(client, "new@example.com", "password123"; data = Dict("full_name" => "Jane Doe"))
```

### Safe background work

```julia
@safe_task begin
    # long-running work that won't crash your process
    println("Background task running")
end
```

### Force a refresh

```julia
refresh_session(client, session)
```

---

## API reference

- `SupabaseClient(base_url::String, anon_key::String)` — Create a client.
- `login(client, email, password)` → `SupabaseSession` — Authenticate and obtain tokens.
- `sign_up(client, email, password; data=Dict())` — Register a user.
- `refresh_session(client, session)` — Refresh tokens and update `session` in-place.
- `is_expired(session)` → `Bool` — Check token expiry (respects leeway).
- `start_auto_refresh(client, session)` / `stop_auto_refresh(session)` — Background refresh control.
- `request(client, session, method, endpoint; body=nothing)` — Authenticated HTTP request helper.

See the implementation for full details: [src/SupabaseAuth.jl](src/SupabaseAuth.jl)

---

## Configuration & best practices

- **DEFAULT_LEEWAY** (default `60`): refresh this many seconds before expiry.
- **MAX_RETRIES** (default `3`): retries for refresh with exponential backoff.

Best practices:

- Start `start_auto_refresh` in long-lived processes (servers, workers).
- Keep service keys on trusted backends; anon keys are for client usage only.

---

## Contributing

- Fork the repo, create a branch, add tests and docs, then open a PR.
- I can help add `examples/` scripts and a `docs/` skeleton (Documenter.jl) on request.

---

## License & security

MIT — see `LICENSE`.

If you discover a security issue, please open a private issue or contact the maintainers.

---

Built with ❤️. Star the repo if it helps you!

