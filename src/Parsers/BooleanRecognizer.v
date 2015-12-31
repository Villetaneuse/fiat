(** * Definition of a boolean-returning CFG parser-recognizer *)
Require Import Coq.Lists.List.
Require Import Coq.Arith.EqNat.
Require Import Coq.Arith.Compare_dec Coq.Arith.Wf_nat.
Require Import Coq.omega.Omega.
Require Import Fiat.Parsers.ContextFreeGrammar.Core.
Require Import Fiat.Parsers.BaseTypes.
Require Import Fiat.Parsers.StringLike.Properties.
Require Import Fiat.Common Fiat.Common.Wf.

Set Implicit Arguments.
Local Open Scope string_like_scope.

Section recursive_descent_parser.
  Context {Char} {HSL : StringLike Char} {G : grammar Char}.
  Context {data : @boolean_parser_dataT Char _}.

  Section bool.
    Section parts.
      Definition parse_item'
                 (str_matches_nonterminal : nonterminal_carrierT -> bool)
                 (str : String)
                 (it : item Char)
      : bool
        := match it with
             | Terminal ch => str ~= [ ch ]
             | NonTerminal nt => str_matches_nonterminal (of_nonterminal nt)
           end.

      Section production.
        Context {len0}
                (parse_nonterminal
                 : forall (str : String) (len : nat),
                     len <= len0
                     -> nonterminal_carrierT
                     -> bool).

        (** To match a [production], we must match all of its items.
            But we may do so on any particular split. *)
        Definition parse_production'_for
                 (splits : production_carrierT -> String -> list nat)
                 (str : String)
                 (len : nat)
                 (pf : len <= len0)
                 (prod_idx : production_carrierT)
        : bool.
        Proof.
          revert str len pf.
          refine
            (list_rect
               (fun _ =>
                  forall (idx : production_carrierT)
                         (str : String)
                         (len : nat)
                         (pf : len <= len0),
                    bool)
               ((** 0-length production, only accept empty *)
                 fun _ str len _ => beq_nat len 0)
               (fun it its parse_production' idx str len pf
                => fold_left
                     orb
                     (map (fun n =>
                             (parse_item'
                                (parse_nonterminal (take n str) (len := min n len) _)
                                (take n str)
                                it)
                               && parse_production' (production_tl idx) (drop n str) (len - n) _)%bool
                          (splits idx str))
                     false)
               (to_production prod_idx)
               prod_idx);
          clear -pf;
          abstract (try apply Min.min_case_strong; omega).
        Defined.

        Definition parse_production'
                 (str : String)
                 (len : nat)
                 (pf : len <= len0)
                 (prod_idx : production_carrierT)
        : bool
          := parse_production'_for split_string_for_production str pf prod_idx.
      End production.

      Section productions.
        Context {len0}
                (parse_nonterminal
                 : forall (str : String)
                          (len : nat)
                          (pf : len <= len0),
                     nonterminal_carrierT -> bool).

        (** To parse as a given list of [production]s, we must parse as one of the [production]s. *)
        Definition parse_productions'
                   (str : String)
                   (len : nat)
                   (pf : len <= len0)
                   (prods : list production_carrierT)
        : bool
          := fold_right orb
                        false
                        (map (parse_production' parse_nonterminal str pf)
                             prods).
      End productions.


      Section nonterminals.
        Section step.
          Context {len0 valid_len}
                  (parse_nonterminal
                   : forall (p : nat * nat),
                       prod_relation lt lt p (len0, valid_len)
                       -> forall (valid : nonterminals_listT)
                                 (str : String) (len : nat),
                            len <= fst p -> nonterminal_carrierT -> bool).

          Definition parse_nonterminal_step
                     (valid : nonterminals_listT)
                     (str : String)
                     (len : nat)
                     (pf : len <= len0)
                     (nt : nonterminal_carrierT)
          : bool.
          Proof.
            refine
              (option_rect
                 (fun _ => bool)
                 (fun parse_nonterminal
                  => parse_productions'
                       parse_nonterminal
                       str
                       (len := len)
                       (sumbool_rect
                          (fun b => len <= (if b then len else len0))
                          (fun _ => le_n _)
                          (fun _ => _)
                          (lt_dec len len0))
                       (nonterminal_to_production nt))
                 false
                 (sumbool_rect
                    (fun b => option (forall (str' : String) (len' : nat), len' <= (if b then len else len0) -> nonterminal_carrierT -> bool))
                    (fun _ => (** [str] got smaller, so we reset the valid nonterminals list *)
                       Some (@parse_nonterminal
                               (len, nonterminals_length initial_nonterminals_data)
                               (or_introl _)
                               initial_nonterminals_data))
                    (fun _ => (** [str] didn't get smaller, so we cache the fact that we've hit this nonterminal already *)
                       sumbool_rect
                         (fun _ => option (forall (str' : String) (len' : nat), len' <= len0 -> nonterminal_carrierT -> bool))
                         (fun is_valid => (** It was valid, so we can remove it *)
                            Some (@parse_nonterminal
                                    (len0, pred valid_len)
                                    (or_intror (conj eq_refl _))
                                    (remove_nonterminal valid nt)))

                         (fun _ => (** oops, we already saw this nonterminal in the past.  ABORT! *)
                            None)
                         (Sumbool.sumbool_of_bool (negb (EqNat.beq_nat valid_len 0) && is_valid_nonterminal valid nt)))
                    (lt_dec len len0)));
            first [ assumption
                  | simpl;
                    generalize (proj1 (proj1 (Bool.andb_true_iff _ _) is_valid));
                    clear; intro;
                    abstract (
                        destruct valid_len; try apply Lt.lt_n_Sn; [];
                        exfalso; simpl in *; congruence
                  ) ].
          Defined.
        End step.

        Section wf.
          (** TODO: add comment explaining signature *)
          Definition parse_nonterminal_or_abort
          : forall (p : nat * nat)
                   (valid : nonterminals_listT)
                   (str : String) (len : nat),
              len <= fst p
              -> nonterminal_carrierT
              -> bool
            := @Fix
                 (nat * nat)
                 _
                 (well_founded_prod_relation lt_wf lt_wf)
                 _
                 (fun sl => @parse_nonterminal_step (fst sl) (snd sl)).

          Definition parse_nonterminal'
                     (str : String)
                     (nt : nonterminal_carrierT)
          : bool
            := @parse_nonterminal_or_abort
                 (length str, nonterminals_length initial_nonterminals_data)
                 initial_nonterminals_data
                 str (length str)
                 (le_n _) nt.

          Definition parse_nonterminal
                     (str : String)
                     (nt : String.string)
          : bool
            := parse_nonterminal' str (of_nonterminal nt).
        End wf.
      End nonterminals.

      Definition parse_item
                 (str : String)
                 (it : item Char)
      : bool
        := parse_item' (parse_nonterminal' str) str it.

      Definition parse_production
                 (str : String)
                 (pat : production_carrierT)
      : bool
        := parse_production' (parse_nonterminal_or_abort (length str, nonterminals_length initial_nonterminals_data) initial_nonterminals_data) str (reflexivity _) pat.

      Definition parse_productions
                 (str : String)
                 (pats : list production_carrierT)
      : bool
        := parse_productions' (parse_nonterminal_or_abort (length str, nonterminals_length initial_nonterminals_data) initial_nonterminals_data) str (reflexivity _) pats.
    End parts.
  End bool.
End recursive_descent_parser.
