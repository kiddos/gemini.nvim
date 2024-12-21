# gemini.nvim

This plugin try to interface Google's Gemini API into neovim.


## Features

- Code Complete
- Code Explain
- Unit Test Generation
- Code Review
- Hints
- Chat

### Code Complete

### Code Explain

### Unit Test generation

### Code Review

### Hints

### Chat


## Installation

- install `curl`

```
sudo apt install curl
```

```shell
export GEMINI_API_KEY="<your API key here>"
```

* [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'kiddos/gemini.nvim',
  build = { 'pip install -r requirements.txt', ':UpdateRemotePlugins' },
  config = function()
    require('gemini').setup()
  end
}
```


* [packer.nvim](https://github.com/wbthomason/packer.nvim)


```lua
use {
  'kiddos/gemini.nvim',
  run = { 'pip install -r requirements.txt', ':UpdateRemotePlugins' },
  config = function()
    require('gemini').setup()
  end,
}
```

## Settings
