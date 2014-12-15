open Ocamlbuild_plugin

let () = dispatch (
  function
  | After_rules ->
    flag ["ocaml"; "ocamldep"; "use_include"] & S[A"-ppx"; A"src/ppx_include.native"];
    flag ["ocaml"; "compile";  "use_include"] & S[A"-ppx"; A"src/ppx_include.native"]
  | _ -> ())
