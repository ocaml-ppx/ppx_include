open Ocamlbuild_plugin

let () = dispatch (
  function
  | After_rules ->
    flag ["ocaml"; "ocamldep"; "use_include"] & S[A"-ppx"; A"src/ppx_include.native"];
    flag ["ocaml"; "compile";  "use_include"] & S[A"-ppx"; A"src/ppx_include.native"];

    dep ["file:src_test/test_ppx_include.ml"]
        ["src_test/a.mli"; "src_test/b.mli"; "src_test/a.ml"; "src_test/b.ml"]
  | _ -> ())
