# nim-c-library-guide

This repository provides resources and examples for building and consuming C libraries created in Nim.

In the `templates` directory, you’ll find various submodules with templates and detailed instructions for building both the libraries and their bindings in different programming languages. Refer to each submodule’s README for specific guidance.

To clone all its submodules locally, run the following command in the root directory of the repository:

```
git submodule update --init --recursive
```

### Notes

- A Rust bindings template is planned but not yet ready. In the meantime, please refer to [waku-rust-bindings](https://github.com/waku-org/waku-rust-bindings) as an example for how to implement a Rust wrapper for your library
