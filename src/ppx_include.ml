open Longident
open Asttypes
open Parsetree
open Ast_mapper
open Ast_helper

let raise_errorf ?sub ?if_highlight ?loc message =
  message |> Printf.kprintf (fun str ->
    let err = Location.error ?sub ?if_highlight ?loc str in
    raise (Location.Error err))

let filename_of_payload ~loc payload =
  match payload with
  | PStr [{ pstr_desc = Pstr_eval (
      { pexp_desc = Pexp_constant (Const_string (file, None)) }, _) }] ->
    file
  | _ ->
    raise_errorf ~loc "[%%include]: invalid syntax"

let name_of_payload ~loc payload =
  let basename = Filename.(chop_extension (basename (filename_of_payload ~loc payload))) in
  String.capitalize basename

let lexbuf_of_payload ~loc payload =
  let filename = filename_of_payload ~loc payload in
  let load_paths =
    (Filename.dirname loc.Location.loc_start.Lexing.pos_fname :: !Config.load_path) |>
    List.map (fun dir -> Filename.concat dir filename)
  in
  try
    load_paths |>
    List.find (fun intf -> Sys.file_exists intf) |>
    open_in |>
    Lexing.from_channel
  with Not_found ->
    raise_errorf ~loc "[%%include]: cannot locate file %S" filename

let introduced_names = ref []

let map_name { txt; loc } =
  if List.exists ((=) txt) !introduced_names then
    { txt = txt ^ "'"; loc }
  else
    { txt; loc }

let rec structure mapper items =
  match items with
  | { pstr_desc = Pstr_module ({pmb_name} as pmb) } as item :: items ->
    { item with pstr_desc = Pstr_module {
        (mapper.module_binding mapper pmb) with pmb_name = map_name pmb_name } } ::
      structure mapper items
  | { pstr_desc = Pstr_recmodule (pmbs) } as item :: items ->
    { item with pstr_desc = Pstr_recmodule
        (List.map (fun ({pmb_name} as pmb) -> {
          (mapper.module_binding mapper pmb) with pmb_name = map_name pmb_name}) pmbs) } ::
      structure mapper items
  | { pstr_desc = Pstr_extension (({ txt = "include"; loc }, payload), _) } :: items ->
    if Ast_mapper.tool_name () = "ocamldep" then begin
      let name = name_of_payload ~loc payload in
      introduced_names := name :: !introduced_names;
      [Str.include_ { pincl_mod = Mod.ident (Location.mknoloc (Lident name));
                      pincl_loc = Location.none; pincl_attributes = [] }]
    end else begin
      mapper.structure mapper (Parse.implementation (lexbuf_of_payload ~loc payload))
    end @ structure mapper items
  | item :: items ->
    mapper.structure_item mapper item :: structure mapper items
  | [] -> []

let rec signature mapper items =
  match items with
  | { psig_desc = Psig_extension (({ txt = "include"; loc }, payload), _) } :: items ->
    if Ast_mapper.tool_name () = "ocamldep" then begin
      let name = name_of_payload ~loc payload in
      introduced_names := name :: !introduced_names;
      [Sig.include_ { pincl_mod = Mty.ident (Location.mknoloc (Lident name));
                      pincl_loc = Location.none; pincl_attributes = [] }]
    end else begin
      mapper.signature mapper (Parse.interface (lexbuf_of_payload ~loc payload))
    end @ signature mapper items
  | item :: items ->
    mapper.signature_item mapper item :: signature mapper items
  | [] -> []

let () =
  Ast_mapper.register "ppx_include" (fun argv ->
    { default_mapper with structure; signature; })
