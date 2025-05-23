# Example Clock Go Bindings

This repository provides Go bindings for the Example Clock library, enabling seamless integration with Go projects.

You can find instructions on how to adapt each file to create Go bindings for your Nim library. All the logic is on `clock.go`

It is recommended for the Go bindings to on its own repo. For the sake of this guide's usability, we added the code of the bindings as a directory of an existing repo.

For an example on how it looks on its own repo and how to integrate the module in other Go projects, please refer to [waku-go-bindings](https://github.com/waku-org/waku-go-bindings)

### How to build

Build the dependencies by running in the `go-bindings` directory:

```
make -C clock
```

### How to test

in the `go-bindings` directory, please run

```
go test -v ./...
```
