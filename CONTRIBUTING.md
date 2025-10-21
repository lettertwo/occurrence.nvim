# Contributing to occurrence.nvim

Thank you for your interest in contributing to occurrence.nvim! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Issues

- Search existing issues before creating a new one
- Provide clear reproduction steps
- Include Neovim version and plugin configuration
- Share minimal test cases when possible

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes following the guidelines below
4. Write or update tests as needed
5. Ensure all tests pass: `make test`
6. Update documentation if needed
7. Submit a pull request

## Development Guidelines

### Commit Message Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automated changelog generation.

#### Quick Setup

**1. Install git hooks for local validation:**

```bash
make install-hooks
```

This installs a commit-msg hook that validates your commit messages locally before they're committed.

**2. Set up the commit message template (optional but recommended):**

```bash
git config commit.template .gitmessage
```

Now when you run `git commit` (without `-m`), your editor will open with the template pre-filled with examples and guidelines.

#### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Type

Must be one of:

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Code style changes (formatting, missing semicolons, etc.)
- **refactor**: Code changes that neither fix bugs nor add features
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **build**: Changes to build system or dependencies
- **ci**: Changes to CI configuration files and scripts
- **chore**: Other changes that don't modify src or test files
- **revert**: Reverts a previous commit

#### Scope

Optional. Can be anything specifying the place of the commit change:

- `api` - API changes
- `config` - Configuration changes
- `operators` - Operator-related changes
- `actions` - Action-related changes
- `keymap` - Keymap changes
- `extmarks` - Extmark/highlighting changes
- `tests` - Test-related changes
- `docs` - Documentation changes

#### Subject

- Use imperative, present tense: "change" not "changed" nor "changes"
- Don't capitalize the first letter
- No period (.) at the end
- Limit to 72 characters

#### Body

Optional. Provide additional context about the change:

- Explain the motivation for the change
- Contrast this with previous behavior
- Use imperative, present tense

#### Footer

Optional. Reference issues and include breaking changes:

- Reference issues: `Fixes #123`, `Closes #456`
- Breaking changes: Start with `BREAKING CHANGE:` followed by description

#### Examples

```
feat(operators): add support for 'p' (put) operator

Add new 'put' operator that replaces marked occurrences with
register content. Useful for bulk replacements.

Closes #42
```

```
fix(api): prevent extmark errors on buffer delete

When a buffer is deleted, extmarks may throw errors if accessed.
Add proper buffer validity checks before extmark operations.

Fixes #78
```

```
docs: add custom operator configuration examples

Add examples showing how to create line-based operators (dd, yy, cc)
and vim-mode-plus style keybindings.
```

```
refactor(keymap)!: simplify configuration API

BREAKING CHANGE: Remove 'actions' and 'preset_actions' config options.
Replace with 'default_keymaps' boolean and 'on_preset_activate' callback.

Migration guide:
- Set default_keymaps = false to disable default keymaps
- Use on_preset_activate callback for custom preset keymaps
- Use <Plug> mappings for entry keymaps

Closes #89
```

### Code Style

- Use 2 spaces for indentation
- Format code with [stylua](https://github.com/JohnnyMorganz/StyLua): `stylua .`
- Follow existing code patterns and conventions
- Add LuaCATS type annotations for public APIs
- Keep lines under 120 characters (see `stylua.toml`)

### Testing

- Write tests for new features using [busted](https://lunarmodules.github.io/busted/)
- Ensure existing tests pass: `make test`
- Add performance tests for performance-critical features
- Run tests in isolation: `busted tests/path/to/test_spec.lua`

### Documentation

- Update README.md for user-facing changes
- Add/update LuaCATS annotations for API changes
- Regenerate vim help: `make doc`
- Document breaking changes clearly
- Add examples for new features

## Project Structure

```
.
├── lua/
│   ├── occurrence.lua           # Main entry point
│   └── occurrence/
│       ├── Occurrence.lua       # Core occurrence class
│       ├── BufferState.lua      # Per-buffer state
│       ├── Config.lua           # Configuration handling
│       ├── api.lua              # Action definitions
│       ├── operators.lua        # Operator definitions
│       └── ...                  # Supporting modules
├── tests/
│   ├── occurrence/              # Unit tests
│   └── perf_spec.lua            # Performance tests
├── doc/
│   └── occurrence.nvim.txt      # Auto-generated vim help
├── .github/workflows/           # CI/CD configuration
├── README.md                    # User documentation
├── CHANGELOG.md                 # Auto-generated changelog
└── CONTRIBUTING.md              # This file
```

## Release Process

Releases are **fully automated** using [Release Please](https://github.com/googleapis/release-please):

### How It Works

1. **Commit to main**: Push commits following [Conventional Commits](#commit-message-convention) to the `main` branch
2. **Automatic PR Creation**: Release Please automatically:
   - Analyzes commits since last release
   - Determines next version based on commit types (feat = minor, fix = patch, breaking = major)
   - Generates/updates CHANGELOG.md
   - Creates a "Release PR" with all changes
3. **Review and Merge**: Review the Release PR and merge when ready
4. **Automatic Release**: On merge, Release Please:
   - Creates a GitHub release with the changelog
   - Tags the release (e.g., `v1.2.3`)
   - Triggers the release workflow (tests + publish)

### Manual Release (if needed)

If you need to create a release manually:

1. Ensure all changes are merged to `main`
2. Create and push a version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. GitHub Actions will:
   - Run all tests
   - Create GitHub release

### Version Bumping Rules

Release Please uses commit types to determine version bumps:

- `feat:` → Minor version bump (0.1.0 → 0.2.0)
- `fix:`, `perf:` → Patch version bump (0.1.0 → 0.1.1)
- `feat!:`, `fix!:`, or `BREAKING CHANGE:` → Major version bump (0.1.0 → 1.0.0)
- `docs:`, `style:`, `refactor:`, `test:`, `chore:` → No version bump (included in next release)

## Getting Help

- Check existing documentation in README.md
- Search closed issues for similar questions
- Open a new issue with your question
- Join discussions in GitHub Discussions (if enabled)

## License

By contributing to occurrence.nvim, you agree that your contributions will be licensed under the MIT License.
