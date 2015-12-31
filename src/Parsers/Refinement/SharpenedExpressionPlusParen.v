(** Sharpened ADT for an expression grammar with + and () *)
Require Import Fiat.Parsers.Refinement.Tactics.
Require Import Fiat.Parsers.Grammars.ExpressionNumPlusParen.
Require Import Fiat.Parsers.Refinement.BinOpBrackets.MakeBinOpTable.
Require Import Fiat.Parsers.Refinement.BinOpBrackets.BinOpRules.
Require Import Fiat.Parsers.ExtrOcamlParsers. (* for simpl rules for [find_first_char_such_that] *)

Set Implicit Arguments.

Section IndexedImpl.

  Lemma ComputationalSplitter'
  : FullySharpened (string_spec plus_expr_grammar string_stringlike).
  Proof.
    start sharpening ADT.
    Time start honing parser using indexed representation.

    Time hone method "splits".
    {
      Time simplify parser splitter.
      let lem := constr:(@refine_binop_table_idx _ _ _ _) in
      setoid_rewrite lem;
        [ | try solve [reflexivity | repeat esplit ].. ];
        [ | solve [reflexivity | repeat esplit ].. ];
        presimpl_after_refine_binop_table.
      finish honing parser method.
    }

    finish_Sharpening_SplitterADT.
  Defined.

  Lemma ComputationalSplitter
  : FullySharpened (string_spec plus_expr_grammar string_stringlike).
  Proof.
    make_simplified_splitter ComputationalSplitter'.
  Defined.

End IndexedImpl.

Require Import Fiat.Parsers.ParserFromParserADT.
Require Import Fiat.Parsers.ExtrOcamlParsers.
Import Fiat.Parsers.ExtrOcamlParsers.HideProofs.

Definition paren_expr_parser (str : String.string) : bool.
Proof.
  Time make_parser ComputationalSplitter. (* 20 s *)
(*  Show Proof.

  pose (has_parse (parser ComputationalSplitter) str) as p.
  Timeout 5 cbv beta iota zeta delta [has_parse parser ParserImplementationOptimized.parser transfer_parser projT1 projT2] in p.
  Timeout 5 simpl map in p.
  Timeout 5 simpl hd in p.
  Timeout 5 simpl Datatypes.length in p.
  Timeout 5 simpl @fst in p.
  Timeout 5 simpl @snd in p.
  Timeout 5 unfold fold_right, fold_left, map in p.
  Timeout 5 simpl @fst in p.
  Timeout 5 simpl @snd in p.
  Timeout 5 unfold map in p.
  Timeout 5 unfold BooleanRecognizer.parse_production' in p.
  About split_string_for_production.
Definition Let_In {A P} (x : A) (f : forall x : A, P x) := let a := x in f a.
Strategy expand [Let_In].
  Timeout 50 let pbody := (eval unfold p in p) in
  lazymatch pbody with
  | appcontext [@split_string_for_production ?Char ?HSL ?pdata ?it (Terminal "+"%char::?ps) (?str, _)]
    => idtac;
      let c1 := constr:(@split_string_for_production Char HSL pdata it (Terminal "+"%char::ps)) in
      let T := type of str in
      let c2 := constr:(fun sz : T * _ => c1 (str, snd sz)) in
      set (splitsv := c2);
      lazymatch eval pattern c1 in pbody with
        | ?pbody' _ => idtac; change pbody with (Let_In splitsv pbody') in p
  end
end.
  Timeout 5 cbv beta in p.
  Timeout 5 simpl in splitsv.
  About list_of_next_bin_ops_opt.
  Timeout 30 let splitsv' := (eval unfold splitsv in splitsv) in
            let c1 := match splitsv' with appcontext[@list_of_next_bin_ops_opt ?a ?b] => constr:(@list_of_next_bin_ops_opt a b) end in
            lazymatch eval pattern c1 in splitsv' with
              | ?splitsv'' _ => idtac;
                               change splitsv with (Let_In c1 splitsv'') in p
  end.
  Timeout 20 cbv beta in p.
  let pbody := (eval unfold p in p) in exact pbody.*)
Defined.
(*Opaque Let_In.
Definition paren_expr_parser' (str : String.string) : bool
  := Eval hnf in paren_expr_parser str.
Transparent Let_In.*)

Print paren_expr_parser.

Recursive Extraction paren_expr_parser.
