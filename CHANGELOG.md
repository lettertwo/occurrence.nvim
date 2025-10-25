# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Modern documentation generation with panvimdoc
- Automated release management with LuaRocks
- LuaCATS annotations for type safety
- Comprehensive performance tests
- CI/CD workflows for testing and releases
- Support for modern plugin managers (rocks.nvim, lazy.nvim v11)

### Changed

- Replaced lemmy-help with panvimdoc for documentation generation
- Updated README.md with comprehensive usage examples
- Modernized project structure following 2024 best practices
- Improved Makefile with better test targets

### Fixed

- Performance test thresholds and memory leak detection
- Better error handling and resource cleanup

## [0.1.0] - Initial Release

### Added

- Core occurrence functionality
- Multiple interaction modes (occurrence mode, operator-modifier)
- Smart occurrence detection (word, selection, search patterns)
- Visual highlighting using Neovim's extmarks system
- Native vim operator integration
- Configurable keymaps and behavior
- Performance optimizations for large files

[Unreleased]: https://github.com/lettertwo/occurrence.nvim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/lettertwo/occurrence.nvim/releases/tag/v0.1.0
