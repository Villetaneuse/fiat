(** * Implementation of simply-typed interface of the parser *)
Require Export Fiat.Parsers.ParserInterface.
Require Import Fiat.Parsers.ContextFreeGrammar.Core.
Require Import Fiat.Parsers.ContextFreeGrammar.Properties.
Require Import Fiat.Parsers.BooleanRecognizer Fiat.Parsers.BooleanRecognizerCorrect.
Require Import Fiat.Parsers.Splitters.RDPList.
Require Import Fiat.Parsers.BaseTypes Fiat.Parsers.CorrectnessBaseTypes.
Require Import Fiat.Parsers.StringLike.Core.
Require Import Fiat.Parsers.MinimalParseOfParse.
Require Import Fiat.Parsers.ContextFreeGrammar.Valid.
Require Import Fiat.Common.
Require Import Fiat.Common.Equality.

Set Implicit Arguments.

Local Open Scope list_scope.

Section implementation.
  Context {Char} {G : grammar Char}.
  Context (splitter : Splitter G).

  Let predata := @rdp_list_predata _ G.
  Local Existing Instance predata.

  Local Instance parser_split_data : @split_dataT Char _ _ :=
    { split_string_for_production idx str
      := splits_for splitter str idx }.

  Local Instance parser_data : @boolean_parser_dataT Char _ :=
    { predata := rdp_list_predata (G := G);
      split_data := parser_split_data }.

  Local Arguments split_string_for_production : simpl never.

  Local Instance parser_completeness_data : @boolean_parser_completeness_dataT' Char _ G parser_data
    := { split_string_for_production_complete str0 valid str pf nt Hvalid := _ }.
  Proof.
    apply initial_nonterminals_correct in Hvalid.
    generalize (fun idx Hvalid' it its Heqb n pf pit pits prefix H' => @splits_for_complete Char G splitter str idx Hvalid' it its Heqb n pf (ex_intro _ nt (ex_intro _ prefix (conj Hvalid H'))) pit pits).
    clear Hvalid.
    induction (G nt) as [ | x xs IHxs ].
    { intros; constructor. }
    { intro H'.
      simpl.
      split;
        [ clear IHxs
        | apply IHxs;
          intros; eapply H'; try eassumption; [ right; eassumption ] ].
      specialize (fun prefix idx Hvalid' it its Heqb H n pf pit pits => H' idx Hvalid' it its Heqb n pf pit pits prefix (or_introl H)).
      clear -H'.
      induction x as [ | it its IHx ].
      { simpl; constructor. }
      { simpl.
        split;
          [ clear IHx
          | apply IHx;
            intros; subst; eapply (H' (_::_)); try eassumption; reflexivity ].
        intros idx Hvalid Heqb.
        specialize (H' nil idx).
        specialize_by assumption.
        specialize (H' _ _ Heqb).
        specialize_by ltac:(exact eq_refl).
        hnf.
        intros [ n [ pit pits ] ]; simpl in * |- .
        destruct (Compare_dec.le_ge_dec n (length str)).
        { exists n; repeat split; eauto.
          specialize (fun pf =>
                        H' _ pf
                           (parse_of_item__of__minimal_parse_of_item pit)
                           (parse_of_production__of__minimal_parse_of_production pits)).
          rewrite Min.min_r by assumption.
          apply H'; eauto. }
        { exists (length str).
          specialize (H' (length str) (reflexivity _)).
          pose proof (fun H => expand_minimal_parse_of_item (str' := take (length str) str) (or_introl (reflexivity _)) (reflexivity _) (or_introl (reflexivity _)) H pit) as pit'; clear pit.
          pose proof (fun H => expand_minimal_parse_of_production (str' := drop (length str) str) (or_introl (reflexivity _)) (reflexivity _) (or_introl (reflexivity _)) H pits) as pits'; clear pits.
          rewrite Min.min_idempotent.
          refine ((fun ret => let pit'' := pit' (fst (snd ret)) in
                              let pits'' := pits' (snd (snd ret)) in
                              ((H' (fst (fst ret) pit'') (snd (fst ret) pits''), pit''), pits'')) _); repeat split.
          { intro p.
            exact (@parse_of_item__of__minimal_parse_of_item Char splitter G _ _ _ _ _ _ p). }
          { intro p.
            exact (@parse_of_production__of__minimal_parse_of_production Char splitter G _ _ _ _ _ _ p). }
          { rewrite !take_long; (assumption || reflexivity). }
          { apply bool_eq_empty; rewrite drop_length; omega. } } } }
  Qed.
Set Printing Implicit. Set Printing Coercions.
  Program Definition parser (Hvalid : grammar_valid G) : Parser G splitter
    := {| has_parse str := parse_nonterminal (data := parser_data) str (Start_symbol G);
          has_parse_sound str Hparse := parse_nonterminal_sound (data := parser_data) Hvalid _ _ Hparse;
          has_parse_complete str p := _ |}.
  Next Obligation.
  Proof.
    dependent destruction p.
    pose proof (fun pf => @parse_of_nonterminal_complete Char splitter _ G _ _ rdp_list_rdata' Hvalid str (Start_symbol G) pf p) as H'.
    apply H'; assumption.
  Qed.
End implementation.
