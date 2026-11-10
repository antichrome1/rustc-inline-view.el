# rustc-inline-view.el

Get visual feedback of what rust code was successfully inlined (or
not) by the rust compiler in your project.

![](./getrandom_example.png)

- NOTE: Depends on cargo, grep, awk and sh (grep and awk will be removed in next release)
- NOTE: Your project must use cargo (plain rustc support is WIP)

## Install

```elisp
(use-package rustc-inline-view
  :vc (:url rustc-inline-view "https://github.com/antichrome1/rustc-inline-view.el"))
```

## Usage

- Navigate anywhere in your project folder
- M-x `rustc-inline-view` (NOTE: this compiles all crates in your project)
- M-x `rustc-inline-view-clear-overlays` to clear highlighting from all buffers

## Metadata

License: ISC<br>
AI usage: No AI agents/tools were/are used in this project.<br>
Contact: Aditya Singh <antichrome1@proton.me>
