#if OCAML_VERSION < (4, 03, 0)
#define Pconst_string Const_string
#endif

#if OCAML_VERSION >= (4, 08, 0)
#define Get_load_path Load_path.get_paths ()
#else
#define Get_load_path !Config.load_path
#endif

open Longident
open Asttypes
open Parsetree
open Ast_mapper
open Ast_helper

let raise_errorf ?sub ?if_highlight ?loc message =
  message |> Printf.kprintf (fun str ->
#if OCAML_VERSION >= (4, 08, 0)
    let err = Location.error ?sub ?loc str in
#else
    let err = Location.error ?sub ?if_highlight ?loc str in
#endif
    raise (Location.Error err))

let filename_of_payload ~loc payload =
  match payload with
  | PStr [{ pstr_desc = Pstr_eval (
      { pexp_desc = Pexp_constant (Pconst_string (file, None)) }, _) }] ->
    file
  | _ ->
    raise_errorf ~loc "[%%include]: invalid syntax"

let lexbuf_of_payload ~loc payload =
  let filename = filename_of_payload ~loc payload in
  let load_paths =
    (Filename.dirname loc.Location.loc_start.Lexing.pos_fname :: Get_load_path) |>
    List.map (fun dir -> Filename.concat dir filename)
  in
  try
    load_paths |>
    List.find (fun intf -> Sys.file_exists intf) |>
    open_in |>
    Lexing.from_channel
  with Not_found ->
    raise_errorf ~loc "[%%include]: cannot locate file %S" filename

let rec structure mapper items =
  match items with
  | { pstr_desc = Pstr_extension (({ txt = "include"; loc }, payload), _) } :: items ->
    mapper.structure mapper (Parse.implementation (lexbuf_of_payload ~loc payload))
  | item :: items ->
    mapper.structure_item mapper item :: structure mapper items
  | [] -> []

let rec signature mapper items =
  match items with
  | { psig_desc = Psig_extension (({ txt = "include"; loc }, payload), _) } :: items ->
    mapper.signature mapper (Parse.interface (lexbuf_of_payload ~loc payload))
  | item :: items ->
    mapper.signature_item mapper item :: signature mapper items
  | [] -> []

let () =
  Ast_mapper.register "ppx_include" (fun argv ->
    { default_mapper with structure; signature; })
