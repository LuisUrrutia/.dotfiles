# LuisUrrutia dotfiles

> [!CAUTION]
> This configurations and installations only works in macOS.

## Install

```sh
cd $HOME && git clone https://github.com/LuisUrrutia/.dotfiles.git && cd .dotfiles && ./install.sh
```

## Things to do after install
- [ ] Add OpenAI API Key to iTerm

## Special features
- **Substring history search**

    When pressing the up key, instead of cycling through the entire history, it will match based on the substring.
- **FZF completions**
  
    When pressing the tab key on a known command (with completions), it will display FZF to assist you. In some cases, it will even show a preview.
- **Shell Prompt**

    It uses P10K as a shell prompt, customized to show git information, battery level, time, and many other details.
- **Powerful git**

    It uses Git Delta and Forgit. Delta provides better highlighting for some Git commands like `git diff`, while Forgit integrates FZF with Git, allowing you to do things like view logs with a preview. It also includes aliases for known commands, like `gb` for `git branch` and `gco` for `git checkout`. Additionally, it offers commands like `git authors` and `git recent-branches`, and includes custom configurations.
- **Mise**

    It uses Mise as a version control for applications like Python or Node, functioning similarly to ASDF but with enhanced features.