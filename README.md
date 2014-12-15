[%%include]
===========

_include_ is a syntax extension that allows to include an OCaml source file inside another one.

_include_ requires OCaml 4.02 or later.

Installation
------------

_include_ can be installed via [OPAM](https://opam.ocaml.org):

    $ opam install ppx_include

Usage
-----

In order to use _include_, require the package `ppx_include`.

Syntax
------

The structure item `[%%include "file.ml"]` or signature item `[%%include "file.mli"]`
is replaced with the structure or signature items inside `file.ml` or `file.mli`.
Whether the file is parsed as an interface or an implementation depends on the context
of the `[%%include]` node; the extension is immaterial.
The file can be located anywhere in the OCaml include path.

This can be most useful if you want to have the contents of recursive modules
in several files:

``` ocaml
module rec A : sig [%%include "a.mli"] end = struct [%%include "a.ml"] end
and B : sig [%%include "b.mli"] end = struct [%%include "b.ml"] end
```

Buildsystem integration
-----------------------

If your buildsystem uses separate source and build trees (like ocamlbuild does),
_include_ will not be able to find the included files. Since it is not possible
to use existing mechanisms, such as ocamldep, to provide the dependencies to
the buildsystem, it is necessary to specify dependencies manually.

### ocamlbuild

For ocamlbuild, the `myocamlbuild.ml` file should look like this:

``` ocaml
open Ocamlbuild_plugin

let () = dispatch (
  function
  | After_rules ->
    dep ["file:src_test/test_ppx_include.ml"]
        ["src_test/a.mli"; "src_test/b.mli"; "src_test/a.ml"; "src_test/b.ml"]
  | _ -> ())

```

License
-------

_import_ is distributed under the terms of [MIT license](LICENSE.txt).
