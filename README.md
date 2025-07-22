# occurrence.nvim

## Tests

To run tests, you need to have [busted] and [nlua] installed.

Example setup for macOS using [Homebrew]:

```bash
# Install luarocks...
brew install luarocks
# Configure luarocks to use lua_version 5.1...
luarocks config lua_version 5.1

# Install luajit...
brew install luajit
# Configure luarocks to include luajit...
luarocks config variables.LUA_INCDIR /usr/local/include/luajit-2.1

# Install nlua...
luarocks --local install nlua
# Configure luarocks to use nlua...
luarocks config variables.LUA "$HOME/.luarocks/bin/nlua"

# Install busted...
luarocks --local install busted

# Run tests...
busted

```

[busted]: https://github.com/lunarmodules/busted
[nlua]: https://github.com/mfussenegger/nlua
[Homebrew]: https://brew.sh
