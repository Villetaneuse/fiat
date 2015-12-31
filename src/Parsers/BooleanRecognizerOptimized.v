(** * Definition of a boolean-returning CFG parser-recognizer *)
Require Import Coq.Lists.List Coq.Strings.String.
Require Import Coq.Numbers.Natural.Peano.NPeano Coq.Arith.Compare_dec Coq.Arith.Wf_nat.
Require Import Fiat.Common.List.Operations.
Require Import Fiat.Parsers.ContextFreeGrammar.Core.
Require Import Fiat.Parsers.ContextFreeGrammar.Notations.
Require Import Fiat.Parsers.BaseTypes.
Require Import Fiat.Common Fiat.Common.Wf Fiat.Common.Wf2 Fiat.Common.Telescope.Core.
Require Import Fiat.Parsers.BooleanRecognizer.
Require Import Fiat.Parsers.BooleanRecognizerCorrect.
Require Import Fiat.Parsers.BooleanRecognizerExt.
Require Import Fiat.Parsers.Splitters.RDPList.
Require Import Fiat.Common.Match.
Require Import Fiat.Common.List.ListFacts.
Require Import Fiat.Common.Equality.
Require Export Fiat.Common.SetoidInstances.
Require Export Fiat.Common.List.ListMorphisms.
Require Export Fiat.Common.OptionFacts.
Require Export Fiat.Common.BoolFacts.
Require Export Fiat.Common.NatFacts.
Require Export Fiat.Common.Sigma.
Require Import Fiat.Parsers.StringLike.Core.
Require Import Fiat.Parsers.StringLike.Properties.

Set Implicit Arguments.
Local Open Scope string_like_scope.

Global Arguments string_dec : simpl never.
Global Arguments string_beq : simpl never.
Global Arguments parse_production' _ _ _ _ _ _ _ _ !_.

Section recursive_descent_parser.
  Context {Char} {HSL : StringLike Char} {HSLP : StringLikeProperties Char}
          {ls : list (String.string * productions Char)}.

  Class str_carrier (constT varT : Type)
    := { to_string : constT * varT -> String;
         of_string : String -> constT * varT;
         to_of : forall x, to_string (of_string x) = x;
         of_to : forall x, of_string (to_string x) = x;
         drop_const : forall x n, fst (of_string (drop n x)) = fst (of_string x);
         take_const : forall x n, fst (of_string (take n x)) = fst (of_string x)}.

  Definition str_carrier' (constT varT : Type)
    := { to_string : constT * varT -> StringLike.String
       & { of_string : StringLike.String -> constT * varT
         | (forall x, to_string (of_string x) = x)
           /\ (forall x, of_string (to_string x) = x)
           /\ (forall x n, fst (of_string (drop n x)) = fst (of_string x))
           /\ (forall x n, fst (of_string (take n x)) = fst (of_string x)) } }.

  Definition str_carrier_default {constT varT} (strC : str_carrier' constT varT)
  : str_carrier constT varT.
  Proof.
    refine {| to_string := projT1 strC;
              of_string := proj1_sig (projT2 strC) |};
    apply (proj2_sig (projT2 strC)).
  Defined.

  Context constT varT {strC : str_carrier constT varT}.

  Local Notation G := (list_to_grammar nil ls) (only parsing).

  Let predata := @rdp_list_predata _ G.
  Local Existing Instance predata.

  Context {splitdata : @split_dataT Char _ _}.

  Let data : boolean_parser_dataT :=
    {| split_data := splitdata |}.
  Local Existing Instance data.

  Definition stringlike_lite (constV : constT) : StringLike Char
    := {| String := varT;
          is_char s := is_char (to_string (constV, s));
          length s := length (to_string (constV, s));
          take n s := snd (of_string (take n (to_string (constV, s))));
          drop n s := snd (of_string (drop n (to_string (constV, s))));
          get n s := get n (to_string (constV, s));
          unsafe_get n s := unsafe_get n (to_string (constV, s));
          bool_eq s s' := bool_eq (to_string (constV, s)) (to_string (constV, s')) |}.

  Local Ltac contract_drop_take_t' :=
    idtac;
    match goal with
      | [ |- context[to_string (?x, snd ?y)] ]
        => replace (x, snd y) with y
          by (
              etransitivity; [ apply surjective_pairing | ]; apply f_equal2; trivial;
              rewrite ?take_const, ?drop_const, of_to; reflexivity
            );
          rewrite to_of
    end.

  Local Ltac contract_drop_take_t :=
    idtac;
    match goal with
      | _ => contract_drop_take_t'
      | [ H : is_true (bool_eq ?x ?y) |- _ ] => change (beq x y) in H
      | [ H : context[is_true (bool_eq ?x ?y)] |- _ ] => change (is_true (bool_eq x y)) with (beq x y) in H
      | [ |- context[is_true (bool_eq ?x ?y)] ] => change (is_true (bool_eq x y)) with (beq x y)
      | _ => progress subst
      | [ H : beq _ _ |- _ ] => rewrite !H; clear H
      | [ |- _ = _ ] => reflexivity
      | [ |- beq _ _ ] => reflexivity
      | [ |- Equivalence _ ] => split; repeat intro
    end.

  Lemma stringlikeproperties_lite (constV : constT) : @StringLikeProperties Char (stringlike_lite constV).
  Proof.
    destruct HSLP;
    split; simpl;
    unfold Proper, respectful, beq; simpl;
    repeat first [ progress contract_drop_take_t
                 | intro
                 | eauto with nocore ].
  Qed.

  Definition split_data_lite (constV : constT) : @split_dataT _ (stringlike_lite constV) _
    := {| split_string_for_production idx s := split_string_for_production idx (to_string (constV, s)) |}.

  Definition data_lite (constV : constT) : @boolean_parser_dataT _ (stringlike_lite constV)
    := {| split_data := split_data_lite constV |}.

  Inductive take_or_drop := take_of (n : nat) | drop_of (n : nat).

  Definition make_drops (ls : list take_or_drop) (str : String)
    := fold_right
         (fun td s => match td with
                        | take_of n => take n s
                        | drop_of n => drop n s
                      end)
         str
         ls.

  Arguments make_drops : simpl never.

  Lemma make_drops_eta ls' str
  : (fst (of_string str), snd (of_string (make_drops ls' str))) = of_string (make_drops ls' str).
  Proof.
    revert str; unfold make_drops; induction ls' as [|x xs IHxs]; simpl; intros.
    { rewrite <- surjective_pairing; reflexivity. }
    { etransitivity; [ | symmetry; apply surjective_pairing ].
      destruct x; simpl.
      { rewrite take_const, <- IHxs; reflexivity. }
      { rewrite drop_const, <- IHxs; reflexivity. } }
  Qed.

  Lemma make_drops_eta' ls' ls'' str
  : (fst (of_string (make_drops ls' str)), snd (of_string (make_drops ls'' str))) = of_string (make_drops ls'' str).
  Proof.
    etransitivity; [ | apply make_drops_eta ].
    f_equal.
    unfold make_drops.
    induction ls' as [|x xs IHxs]; simpl; intros; trivial.
    destruct x; rewrite ?take_const, ?drop_const, IHxs; reflexivity.
  Qed.

  Lemma make_drops_eta'' ls' str strv
  : (fst (of_string str), snd (of_string (make_drops ls' (to_string (fst (of_string str), strv))))) = of_string (make_drops ls' (to_string (fst (of_string str), strv))).
  Proof.
    etransitivity; [ | apply make_drops_eta ]; simpl.
    rewrite of_to; simpl; reflexivity.
  Qed.

  Local Ltac t_reduce_fix :=
    repeat match goal with
             | _ => progress simpl sumbool_rect
             | _ => progress simpl option_rect
             | [ |- context[lt_dec ?x ?y] ]
               => destruct (lt_dec x y)
             | [ |- context[dec ?x] ]
               => destruct (dec x)
             | [ |- @fold_right ?A ?B ?f ?x ?ls = @fold_right ?A ?B ?f ?x ?ls' ]
               => apply (_ : Proper (_ ==> _ ==> _ ==> eq) (@fold_right A B))
             | [ |- @fold_left ?A ?B ?f ?ls ?x = @fold_left ?A ?B ?f ?ls' ?x ]
               => apply (_ : Proper (_ ==> _ ==> _ ==> eq) (@fold_left A B))
             | [ |- @map ?A ?B ?f ?ls = @map ?A ?B ?f' ?ls' ]
               => apply (_ : Proper (pointwise_relation _ _ ==> _ ==> eq) (@map A B))
             | _ => intro
             | [ |- ?x = ?x ] => reflexivity
             | [ |- andb _ _ = andb _ _ ] => apply f_equal2
             | [ |- orb _ _ = orb _ _ ] => apply f_equal2
             | [ |- match ?it with Terminal _ => _ | _ => _ end = match ?it with _ => _ end ] => is_var it; destruct it
             | [ |- context[(fst ?x, snd ?x)] ] => rewrite <- !surjective_pairing
             | _ => contract_drop_take_t'
             | _ => rewrite make_drops_eta
             | _ => rewrite make_drops_eta'
             | _ => rewrite make_drops_eta''
             | [ |- context[to_string (of_string _)] ] => rewrite !to_of
             | [ |- context[take ?x (make_drops ?ls ?str)] ]
               => change (take x (make_drops ls str)) with (make_drops (take_of x :: ls) str)
             | [ |- context[drop ?x (make_drops ?ls ?str)] ]
               => change (drop x (make_drops ls str)) with (make_drops (drop_of x :: ls) str)
             | _ => solve [ auto with nocore ]
             | [ |- prod_relation lt lt _ _ ] => hnf; simpl; omega
             | [ H : (_ && _)%bool = true |- _ ] => apply Bool.andb_true_iff in H
             | [ H : _ = in_left |- _ ] => clear H
             | [ H : _ /\ _ |- _ ] => destruct H
             | [ H : context[negb (EqNat.beq_nat ?x ?y)] |- _ ] => destruct (EqNat.beq_nat x y) eqn:?
             | [ H : EqNat.beq_nat _ _ = false |- _ ] => apply EqNat.beq_nat_false in H
             | [ H : EqNat.beq_nat _ _ = true |- _ ] => apply EqNat.beq_nat_true in H
             | [ H : snd ?x = _ |- _ ] => is_var x; destruct x
             | _ => progress simpl negb in *
             | [ H : false = true |- _ ] => inversion H
             | [ |- ?f _ (match ?p with eq_refl => ?k end) = ?f' _ ?k ]
               => destruct p
             | [ |- match ?ls with nil => _ | _ => _ end = match ?ls with _ => _ end ]
               => destruct ls eqn:?
           end.

  Local Ltac t_reduce_list :=
    idtac;
    match goal with
      | [ |- list_rect ?P ?n ?c ?ls ?z (snd (of_string (make_drops ?l ?str))) ?x ?y = list_rect ?P' ?n' ?c' ?ls ?z (make_drops ?l ?str) ?x ?y ]
        => let n0 := fresh in
           let c0 := fresh in
           let n1 := fresh in
           let c1 := fresh in
           set (n0 := n);
             set (n1 := n');
             set (c0 := c);
             set (c1 := c');
             refine (list_rect
                       (fun ls' => forall z' x' y' l', list_rect P n0 c0 ls' z' (snd (of_string (make_drops l' str))) x' y' = list_rect P' n1 c1 ls' z' (make_drops l' str) x' y')
                       _
                       _
                       ls
                       z x y l);
             simpl list_rect;
             [ subst n0 c0 n1 c1; cbv beta
             | intros; unfold n0 at 1, c0 at 1, n1 at 1, c1 at 1 ]
      | [ |- list_rect ?P ?n ?c ?ls (snd (of_string (make_drops ?l ?str))) ?x ?y = list_rect ?P' ?n' ?c' ?ls (make_drops ?l ?str) ?x ?y ]
        => let n0 := fresh in
           let c0 := fresh in
           let n1 := fresh in
           let c1 := fresh in
           set (n0 := n);
             set (n1 := n');
             set (c0 := c);
             set (c1 := c');
             refine (list_rect
                       (fun ls' => forall x' y' l', list_rect P n0 c0 ls' (snd (of_string (make_drops l' str))) x' y' = list_rect P' n1 c1 ls' (make_drops l' str) x' y')
                       _
                       _
                       ls
                       x y l);
             simpl list_rect;
             [ subst n0 c0 n1 c1; cbv beta
             | intros; unfold n0 at 1, c0 at 1, n1 at 1, c1 at 1 ]
      | [ |- list_rect ?P ?n ?c ?ls ?z (snd (of_string (make_drops ?l ?str))) ?x ?y = list_rect ?P' ?n' ?c' ?ls ?z (snd (of_string (make_drops ?l ?str))) ?x ?y ]
        => let n0 := fresh in
           let c0 := fresh in
           let n1 := fresh in
           let c1 := fresh in
           set (n0 := n);
             set (n1 := n');
             set (c0 := c);
             set (c1 := c');
             refine (list_rect
                       (fun ls' => forall z' x' y' l', list_rect P n0 c0 ls' z' (snd (of_string (make_drops l' str))) x' y' = list_rect P' n1 c1 ls' z' (snd (of_string (make_drops l' str))) x' y')
                       _
                       _
                       ls
                       z x y l);
             simpl list_rect;
             [ subst n0 c0 n1 c1; cbv beta
             | intros; unfold n0 at 1, c0 at 1, n1 at 1, c1 at 1 ]
      | [ |- list_rect ?P ?n ?c ?ls (snd (of_string (make_drops ?l ?str))) ?x ?y = list_rect ?P' ?n' ?c' ?ls (snd (of_string (make_drops ?l ?str))) ?x ?y ]
        => let n0 := fresh in
           let c0 := fresh in
           let n1 := fresh in
           let c1 := fresh in
           set (n0 := n);
             set (n1 := n');
             set (c0 := c);
             set (c1 := c');
             refine (list_rect
                       (fun ls' => forall x' y' l', list_rect P n0 c0 ls' (snd (of_string (make_drops l' str))) x' y' = list_rect P' n1 c1 ls' (snd (of_string (make_drops l' str))) x' y')
                       _
                       _
                       ls
                       x y l);
             simpl list_rect;
             [ subst n0 c0 n1 c1; cbv beta
             | intros; unfold n0 at 1, c0 at 1, n1 at 1, c1 at 1 ]
    end.

  Definition parse_nonterminal_opt0
             (str : String)
             (nt : String.string)
  : { b : bool | b = parse_nonterminal str nt }.
  Proof.
    exists (@parse_nonterminal _ _ (data_lite (fst (of_string str))) (snd (of_string str)) nt).
    unfold parse_nonterminal, parse_nonterminal', parse_nonterminal_or_abort.
    simpl.
    rewrite <- !surjective_pairing, !to_of.
    change str with (make_drops nil str).
    lazymatch goal with
      | [ |- Fix ?rwf _ ?P0 ?a ?b ?c ?d ?e ?f = Fix _ _ ?P1 _ _ ?str _ _ _ ]
        => set (a' := a); set (P0' := P0); set (P1' := P1); generalize f; generalize e; change (d <= d) with (d <= (fst a')); generalize d; generalize b; clearbody a';
           generalize (@nil take_or_drop); induction (rwf a') as [?? IH]; intros
    end.
    rewrite !Fix5_eq by (intros; apply parse_nonterminal_step_ext; assumption).
    unfold P0' at 1, P1' at 1, parse_nonterminal_step, parse_productions', parse_production', parse_production'_for, parse_item'.
    t_reduce_fix;
    t_reduce_list;
    t_reduce_fix.
    { apply IH; t_reduce_fix. }
    { apply IH; t_reduce_fix. }
  Defined.

  Local Ltac refine_Fix2_5_Proper_eq :=
    idtac;
    (lazymatch goal with
    | [ |- context[_ = @Fix2 ?A ?A' ?R ?Rwf ?T (fun a0 b0 c0 d0 e0 h0 i0 => @?f a0 b0 c0 d0 e0 h0 i0) ?a ?a' ?b ?c ?d ?e ?h] ]
      => (lazymatch T with
         | (fun a' : ?A0 => forall (b' :@?B a') (c' : @?C a' b') (d' : @?D a' b' c') (e' : @?E a' b' c' d') (h' : @?H a' b' c' d' e'), @?P a' b' c' d' e' h')
           => let H' := fresh in
              (*refine (_ : @Fix A R Rwf T (fun a0 b0 c0 d0 e0 h0 i0 => _) a b c d e h = _);
                 let f' := match goal with |- @Fix _ _ _ _ ?f' _ _ _ _ _ _ = _ => constr:f' end in*)
              pose proof ((fun f' H0 => @Fix2_5_Proper_eq A A' B C D E H R Rwf P f' f H0 a a' b c d e h)) as H';
          cbv beta in H';
          (lazymatch type of H' with
          | forall f' : ?f'T, @?H'T f' -> _
            => let H'' := fresh in
               let f'' := fresh in
               assert (H'' : { f' : f'T & H'T f' });
           [ clear H'
           | destruct H'' as [f'' H''];
             specialize (H' f'' H'');
             clear H''; eexists; exact H' ]
           end)
          end)
     end);
    unfold forall_relation, pointwise_relation, respectful;
    cbv beta;
    eexists (fun a0 a0' b0 c0 d0 e0 h0 i0 => _); intros.

  Local Ltac fin_step_opt :=
    repeat match goal with
             | [ |- _ = true ] => reflexivity
             | [ |- _ = false ] => reflexivity
             | [ |- ?x = ?x ] => reflexivity
             | [ |- _ = ?x ] => is_var x; reflexivity
             | [ |- _ = (_::_) ] => apply f_equal2
             | [ |- _ = nil ] => reflexivity
             | [ |- _ = 0 ] => reflexivity
             | [ |- _ = 1 ] => reflexivity
             | [ |- _ = EqNat.beq_nat _ _ ] => apply f_equal2
             | [ |- _ = leb _ _ ] => apply f_equal2
             | [ |- _ = S _ ] => apply f_equal
             | [ |- _ = string_beq _ _ ] => apply f_equal2
             | [ |- _ = fst ?x ] => is_var x; reflexivity
             | [ |- _ = snd ?x ] => is_var x; reflexivity
             | [ |- context[(0 - _)%natr] ] => rewrite (minusr_minus 0); simpl (minus 0)
             | [ |- _ = (_, _) ] => apply f_equal2
             | _ => progress cbv beta
             | [ |- context[orb _ false] ] => rewrite Bool.orb_false_r
             | [ |- context[orb _ true] ] => rewrite Bool.orb_true_r
             | [ |- context[andb _ false] ] => rewrite Bool.andb_false_r
             | [ |- context[andb _ true] ] => rewrite Bool.andb_true_r
           end.

  Local Ltac step_opt' :=
    idtac;
    match goal with
      | _ => rewrite <- !minusr_minus
      | [ |- _ = @option_rect ?A ?B (fun s => _) _ _ ]
        => refine (_ : @option_rect A B (fun s => _) _ _ = _);
          apply (_ : Proper (pointwise_relation _ _ ==> _ ==> _ ==> eq) (@option_rect A B));
          repeat intro
      | [ |- _ = @bool_rect ?A _ _ _ ]
        => refine (_ : @bool_rect A _ _ _ = _);
          apply (_ : Proper (_ ==> _ ==> _ ==> eq) (@bool_rect A));
          repeat intro
      | [ |- _ = fold_right orb false _ ]
        => rewrite <- !(@fold_symmetric _ orb) by first [ apply Bool.orb_assoc | apply Bool.orb_comm ]
      | [ |- _ = @fold_left ?A ?B orb _ false ]
        => refine (_ : fold_left orb _ false = _);
          apply (_ : Proper (_ ==> _ ==> _ ==> _) (@fold_left A B)); repeat intro
      | [ |- _ = @fold_right ?A ?B (fun x y => _) _ _ ]
        => refine (_ : fold_right (fun x y => _) _ _ = _);
          apply (_ : Proper (_ ==> _ ==> _ ==> _) (@fold_right A B)); repeat intro
      | [ |- _ = @map ?A ?B _ _ ]
        => refine (_ : @map A B (fun x => _) _ = _);
          apply (_ : Proper (pointwise_relation _ _ ==> _ ==> _) (@map A B)); repeat intro
      | [ |- _ = @nth ?A _ _ _ ]
        => rewrite <- nth'_nth
      | [ |- _ = @nth' ?A _ _ _ ]
        => refine (_ : @nth' A _ _ _ = _);
          apply f_equal3
      | [ |- _ = sumbool_rect ?T (fun a => _) (fun b => _) ?c ]
        => refine (_ : sumbool_rect T (fun a => _) (fun b => _) c = _);
          refine (sumbool_rect
                    (fun c' => sumbool_rect T _ _ c' = sumbool_rect T _ _ c')
                    _ _ c); intro; simpl sumbool_rect
      | [ |- ?e = match ?ls with nil => _ | _ => _ end ]
        => is_evar e; refine (_ : match ls with nil => _ | _ => _ end = _)
      | [ |- match ?ls with nil => ?A | x::xs => @?B x xs end = match ?ls with nil => ?A' | x::xs => @?B' x xs end ]
        => refine (match ls
                         as ls'
                         return match ls' with nil => A | x::xs => B x xs end = match ls' with nil => A' | x::xs => B' x xs end
                   with
                     | nil => _
                     | _ => _
                   end)
      | [ |- _ = item_rect ?T ?A ?B ?c ] (* evar kludge following *)
        => revert c;
          let RHS := match goal with |- forall c', _ = ?RHS c' => RHS end in
          let f := constr:(fun TC NC =>
                             forall c, item_rect T TC NC c = RHS c) in
          let f := (eval cbv beta in f) in
          let e1 := fresh in
          let e2 := fresh in
          match type of f with
            | ?X -> ?Y -> _
              => evar (e1 : X); evar (e2 : Y)
          end;
            intro c;
            let ty := constr:(item_rect T e1 e2 c = RHS c) in
            etransitivity_rev _; [ refine (_ : ty) | reflexivity ];
            revert c;
            refine (item_rect
                      (fun c => item_rect T e1 e2 c = RHS c)
                      _ _);
            intro c; simpl @item_rect; subst e1 e2
    end;
    fin_step_opt.

  Local Ltac step_opt := repeat step_opt'.

  Local Ltac sigL_transitivity term :=
    idtac;
    (lazymatch goal with
    | [ |- ?sig (fun x : ?T => @?A x = ?B) ]
      => (let H := fresh in
          let H' := fresh in
          assert (H : sig (fun x : T => A x = term));
          [
          | assert (H' : term = B);
            [ clear H
            | let x' := fresh in
              destruct H as [x' H];
                exists x'; transitivity term; [ exact H | exact H' ] ] ])
     end).

  Local Ltac fix_trans_helper RHS x y :=
    match RHS with
      | appcontext G[y] => let RHS' := context G[x] in
                           fix_trans_helper RHS' x y
      | _ => constr:RHS
    end.

  Local Ltac fix2_trans :=
    match goal with
      | [ H : forall a0 a0' a1 a2 a3 a4 a5 a6, ?x a0 a0' a1 a2 a3 a4 a5 a6 = ?y a0 a0' a1 a2 a3 a4 a5 a6 |- _ = ?RHS ]
        => let RHS' := fix_trans_helper RHS x y
           in transitivity RHS'; [ clear H y | ]
    end.

  Local Ltac t_reduce_list_more :=
    idtac;
    (lazymatch goal with
    | [ str : String |- list_rect ?P ?n ?c ?ls ?str' ?x ?y = list_rect ?P' ?n' ?c' ?ls ?str' ?x ?y ]
      => (change str' with (snd (fst (of_string str), str'));
          rewrite <- (of_to (fst (of_string str), str'));
          change (to_string (fst (of_string str), str')) with (make_drops nil (to_string (fst (of_string str), str')));
          t_reduce_list)
    | [ str : String |- list_rect ?P ?n ?c ?ls ?z ?str' ?x ?y = list_rect ?P' ?n' ?c' ?ls ?z ?str' ?x ?y ]
      => (change str' with (snd (fst (of_string str), str'));
          rewrite <- (of_to (fst (of_string str), str'));
          change (to_string (fst (of_string str), str')) with (make_drops nil (to_string (fst (of_string str), str')));
          t_reduce_list)
     end).

  Local Ltac t_prereduce_list_evar :=
    idtac;
    match goal with
      | [ |- ?e = list_rect ?P (fun a b c d => _) (fun x xs H a b c d => _) ?ls ?A ?B ?C ?D ]
        => refine (_ : list_rect P _ _ ls A B C D = _)
    end.

  Local Ltac t_reduce_list_evar :=
    t_prereduce_list_evar;
    match goal with
      | [ |- list_rect ?P ?N ?C ?ls ?a ?b ?c ?d = list_rect ?P ?N' ?C' ?ls ?a ?b ?c ?d ]
        => let P0 := fresh in
           let N0 := fresh in
           let C0 := fresh in
           let N1 := fresh in
           let C1 := fresh in
           set (P0 := P);
             set (N0 := N);
             set (C0 := C);
             set (N1 := N');
             set (C1 := C');
             let IH := fresh "IH" in
             let xs := fresh "xs" in
             refine (list_rect
                       (fun ls' => forall a' b' c' d',
                                     list_rect P0 N0 C0 ls' a' b' c' d'
                                     = list_rect P0 N1 C1 ls' a' b' c' d')
                       _
                       _
                       ls a b c d);
               simpl @list_rect;
               [ subst P0 N0 C0 N1 C1; intros; cbv beta
               | intros ? xs IH; intros; unfold C0 at 1, C1 at 1; cbv beta;
                 setoid_rewrite <- IH; clear IH N1 C1;
                 generalize (list_rect P0 N0 C0 xs); intro ]
    end.

  Local Ltac t_refine_item_match_terminal :=
    idtac;
    match goal with
      | [ |- _ = match ?it with Terminal _ => _ | NonTerminal nt => @?NT nt end :> ?T ]
        => refine (_ : item_rect (fun _ => T) _ NT it = _);
          revert it;
          refine (item_rect
                    _
                    _
                    _); simpl @item_rect; intro;
          [ | reflexivity ]
    end.

  Local Ltac t_refine_item_match :=
    idtac;
    (lazymatch goal with
      | [ |- _ = match ?it with Terminal _ => _ | _ => _ end :> ?T ]
        => (refine (_ : item_rect (fun _ => T) _ _ it = _);
          (lazymatch goal with
            | [ |- item_rect ?P ?TC ?NC it = match it with Terminal t => @?TC' t | NonTerminal nt => @?NC' nt end ]
              => refine (item_rect
                           (fun it' => item_rect (fun _ => T) TC NC it'
                                       = item_rect (fun _ => T) TC' NC' it')
                           _
                           _
                           it)
          end;
          clear it; simpl @item_rect; intro))
    end).

  Local Arguments leb !_ !_.
  Local Arguments to_nonterminal / .

  Lemma list_to_productions_to_nonterminal nt default
  : list_to_productions default ls (to_nonterminal nt)
    = nth
        nt
        (map
           snd
           (uniquize
              (fun x y =>
                 string_beq (fst x) (fst y)) ls))
        default.
  Proof.
    unfold list_to_productions at 1, to_nonterminal at 1; simpl.
    unfold productions, production in *.
    rewrite <- (@uniquize_idempotent _ string_beq (map fst ls)).
    change (uniquize string_beq (map fst ls)) with (Valid_nonterminals G).
    rewrite rdp_list_find_to_nonterminal.
    rewrite pull_bool_rect; simpl.
    rewrite uniquize_idempotent.
    change (uniquize string_beq (map fst ls)) with (Valid_nonterminals G).
    change default with (snd (EmptyString, default)).
    rewrite map_nth; simpl.
    rewrite uniquize_map.
    match goal with
      | [ |- context[uniquize ?beq ?ls] ]
        => set (ls' := uniquize beq ls)
    end.
    repeat match goal with
             | [ |- context G[uniquize ?beq ?ls] ]
               => let G' := context G[ls'] in
                  change G'
           end.
    clearbody ls'.
    revert nt; induction ls' as [|x xs IHxs]; simpl; intro nt;
    destruct nt; simpl; trivial.
  Qed.

  Local Instance good_nth_proper {A}
  : Proper (eq ==> _ ==> _ ==> eq) (nth (A:=A))
    := _.

  Local Ltac rewrite_map_nth_rhs :=
    idtac;
    match goal with
      | [ |- _ = ?RHS ]
        => let v := match RHS with
                      | context[match nth ?n ?ls ?d with _ => _ end]
                        => constr:(nth n ls d)
                      | context[nth ?n ?ls ?d]
                        => constr:(nth n ls d)
                    end in
           let P := match (eval pattern v in RHS) with
                      | ?P _ => P
                    end in
           rewrite <- (map_nth P)
    end.

  Local Ltac rewrite_map_nth_dep_rhs :=
    idtac;
    match goal with
      | [ |- _ = ?RHS ]
        => let v := match RHS with
                      | context[match nth ?n ?ls ?d with _ => _ end]
                        => constr:(nth n ls d)
                      | context[nth ?n ?ls ?d]
                        => constr:(nth n ls d)
                    end in
           let n := match v with nth ?n ?ls ?d => n end in
           let ls := match v with nth ?n ?ls ?d => ls end in
           let d := match v with nth ?n ?ls ?d => d end in
           let P := match (eval pattern v in RHS) with
                      | ?P _ => P
                    end in
           let P := match (eval pattern n in P) with
                      | ?P _ => P
                    end in
           rewrite <- (map_nth_dep P ls d n)
    end.

  Local Ltac t_pull_nth :=
    repeat match goal with
             | _ => rewrite drop_all by (simpl; omega)
             | [ |- _ = nth _ _ _ ] => step_opt'
             | [ |- _ = nth' _ _ _ ] => step_opt'
             | _ => rewrite !map_map
             | _ => progress simpl
             | _ => rewrite <- !surjective_pairing
             | _ => progress rewrite_map_nth_rhs
           end;
    fin_step_opt.
  Local Ltac t_after_pull_nth_fin :=
    idtac;
    match goal with
      | [ |- appcontext[@nth] ] => fail 1
      | [ |- appcontext[@nth'] ] => fail 1
      | _ => repeat step_opt'
    end.

  Let Let_In {A B} (x : A) (f : forall y : A, B y) : B x
    := let y := x in f y.

  Let Let_In_Proper {A B} x
  : Proper (forall_relation (fun _ => eq) ==> eq) (@Let_In A B x).
  Proof.
    lazy; intros ?? H; apply H.
  Defined.

  Definition inner_nth' {A} := Eval unfold nth' in @nth' A.
  Definition inner_nth'_nth' : @inner_nth' = @nth'
    := eq_refl.

  Lemma rdp_list_to_production_opt_sig x
  : { f : _ | rdp_list_to_production (G := G) x = f }.
  Proof.
    eexists.
    set_evars.
    unfold rdp_list_to_production at 1.
    cbv beta iota delta [Carriers.default_to_production productions production].
    simpl @Lookup.
    match goal with
      | [ |- (let a := ?av in
              let b := @?bv a in
              let c := @?cv a b in
              let d := @?dv a b c in
              let e := @?ev a b c d in
              @?v a b c d e) = ?R ]
        => change (Let_In av (fun a =>
                   Let_In (bv a) (fun b =>
                   Let_In (cv a b) (fun c =>
                   Let_In (dv a b c) (fun d =>
                   Let_In (ev a b c d) (fun e =>
                   v a b c d e))))) = R);
          cbv beta
    end.
    lazymatch goal with
      | [ |- Let_In ?x ?P = ?R ]
        => subst R; refine (@Let_In_Proper _ _ x _ _ _); intro; set_evars
    end.
    simpl rewrite list_to_productions_to_nonterminal; simpl.
    symmetry; rewrite_map_nth_rhs; symmetry.
    repeat match goal with
             | [ |- appcontext G[@Let_In ?A ?B ?k ?f] ]
               => first [ let h := head k in constr_eq h @nil
                        | constr_eq k 0
                        | constr_eq k (snd (snd x)) ];
                 test pose f; (* make sure f is closed *)
                 let c := constr:(@Let_In A B k) in
                 let c' := (eval unfold Let_In in c) in
                 let G' := context G[c' f] in
                 change G'; simpl
           end.
    rewrite drop_all by (simpl; omega).
    unfold productions, production.
    rewrite <- nth'_nth at 1.
    rewrite map_map; simpl.
    match goal with
      | [ H := ?e |- _ ] => is_evar e; subst H
    end.
    match goal with
      | [ |- nth' ?a ?ls ?d = ?e ?a ]
        => refine (_ : inner_nth' a ls d = (fun a' => inner_nth' a' _ d) a); cbv beta;
           apply f_equal2; [ clear a | reflexivity ]
    end.
    etransitivity.
    { apply (_ : Proper (pointwise_relation _ _ ==> eq ==> eq) (@List.map _ _));
      [ intro | reflexivity ].
      do 2 match goal with
             | [ |- Let_In ?x ?P = ?R ]
               => refine (@Let_In_Proper _ _ x _ _ _); intro
           end.
      etransitivity.
      { symmetry; rewrite_map_nth_rhs; symmetry.
        unfold Let_In at 2 3 4; simpl.
        set_evars.
        rewrite drop_all by (simpl; omega).
        unfold Let_In.
        rewrite <- nth'_nth.
        change @nth' with @inner_nth'.
        subst_body; reflexivity. }
      reflexivity. }
    reflexivity.
  Defined.

  Definition rdp_list_to_production_opt x
    := Eval cbv beta iota delta [proj1_sig rdp_list_to_production_opt_sig Let_In]
      in proj1_sig (rdp_list_to_production_opt_sig x).

  Lemma rdp_list_to_production_opt_correct x
  : rdp_list_to_production (G := G) x = rdp_list_to_production_opt x.
  Proof.
    exact (proj2_sig (rdp_list_to_production_opt_sig x)).
  Qed.

  Lemma opt_helper_minusr_proof
  : forall {len0 len}, len <= len0 -> forall n : nat, (len - n)%natr <= len0.
  Proof.
    clear.
    intros.
    rewrite minusr_minus; omega.
  Qed.

  Definition parse_nonterminal_opt'0
             (str : String)
             (nt : String.string)
  : { b : bool | b = parse_nonterminal str nt }.
  Proof.
    let c := constr:(parse_nonterminal_opt0 str nt) in
    let h := head c in
    let p := (eval cbv beta iota zeta delta [proj1_sig h] in (proj1_sig c)) in
    sigL_transitivity p; [ | abstract exact (proj2_sig c) ].
    cbv beta iota zeta delta [parse_nonterminal parse_nonterminal' parse_nonterminal_or_abort list_to_grammar].
    change (@parse_nonterminal_step Char) with (fun b c d e f g h i j k => @parse_nonterminal_step Char b c d e f g h i j k); cbv beta.
    evar (b' : bool).
    sigL_transitivity b'; subst b';
    [
    | rewrite Fix5_2_5_eq by (intros; apply parse_nonterminal_step_ext; assumption);
      reflexivity ].
    simpl @fst; simpl @snd.
    cbv beta iota zeta delta [parse_nonterminal parse_nonterminal' parse_nonterminal_or_abort parse_nonterminal_step parse_productions parse_productions' parse_production parse_item parse_item' Lookup list_to_grammar list_to_productions].
    simpl.
    evar (b' : bool).
    sigL_transitivity b'; subst b';
    [
    | rewrite <- !surjective_pairing, !to_of;
      reflexivity ].
    unfold parse_production', parse_production'_for, parse_item', productions, production.
    cbv beta iota zeta delta [predata BaseTypes.predata data_lite initial_nonterminals_data nonterminals_length remove_nonterminal production_carrierT].
    cbv beta iota zeta delta [rdp_list_predata Carriers.default_production_carrierT rdp_list_is_valid_nonterminal rdp_list_initial_nonterminals_data rdp_list_remove_nonterminal Carriers.default_nonterminal_carrierT rdp_list_nonterminals_listT rdp_list_production_tl Carriers.default_nonterminal_carrierT].
    (*cbv beta iota zeta delta [rdp_list_of_nonterminal].*)
    evar (b' : bool).
    sigL_transitivity b'; subst b';
    [
    | rewrite length_up_to;
      simpl;
      match goal with
        | [ |- _ = ?f _ _ _ _ _ _ ]
          => let f' := fresh in
             set (f' := f);
               rewrite !uniquize_idempotent;
               subst f'
      end;
      reflexivity ].
    refine_Fix2_5_Proper_eq.
    rewrite uniquize_idempotent.
    etransitivity_rev _.
    { fix2_trans;
      [
      | solve [ t_reduce_fix;
                t_reduce_list_more;
                t_reduce_fix ] ].
      step_opt'; [ | reflexivity ].
      step_opt'.
      etransitivity_rev _.
      { step_opt'.
        cbv beta iota delta [rdp_list_nonterminal_to_production].
        simpl rewrite list_to_productions_to_nonterminal.
        etransitivity_rev _.
        { step_opt'; [ reflexivity | ].
          etransitivity_rev _.
          { step_opt'.
            rewrite_map_nth_rhs; rewrite !map_map; simpl.
            reflexivity. }
          rewrite_map_nth_dep_rhs; simpl.
          rewrite map_length.
          reflexivity. }
        rewrite_map_nth_rhs; rewrite !map_map; simpl.
        apply f_equal2; [ | reflexivity ].
        step_opt'; [ | reflexivity ].
        rewrite !map_map; simpl.
        reflexivity. }
      rewrite_map_nth_rhs; rewrite !map_map; simpl.
      rewrite <- nth'_nth.
      etransitivity_rev _.
      { step_opt'.
        step_opt'; [ | reflexivity ].
        reflexivity. }
      reflexivity. }
    etransitivity_rev _.
    { etransitivity_rev _.
      { repeat first [ idtac;
                       match goal with
                         | [ |- appcontext[@rdp_list_of_nonterminal] ] => fail 1
                         | [ |- appcontext[@Carriers.default_production_tl] ] => fail 1
                         | _ => reflexivity
                       end
                     | step_opt'
                     | t_reduce_list_evar
                     | apply (f_equal2 andb)
                     | t_refine_item_match ].
        { progress unfold rdp_list_of_nonterminal; simpl.
          rewrite !uniquize_idempotent.
          reflexivity. }
        { match goal with
            | [ |- _ = ?f ?A ?b ?c ?d ]
              => refine (f_equal (fun A' => f A' b c d) _)
          end.
          progress unfold Carriers.default_production_tl; simpl.
          repeat step_opt'; [ reflexivity | ].
          simpl rewrite list_to_productions_to_nonterminal.
          unfold productions, production.
          rewrite_map_nth_rhs; simpl.
          rewrite <- nth'_nth.
          rewrite_map_nth_dep_rhs; simpl.
          step_opt'; simpl.
          rewrite !nth'_nth; simpl.
          rewrite map_length.
          rewrite <- !nth'_nth.
          change @nth' with @inner_nth'.
          reflexivity. } }
      etransitivity_rev _.
      { repeat first [ idtac;
                       match goal with
                         | [ |- appcontext[@rdp_list_to_production] ] => fail 1
                         | _ => reflexivity
                       end
                     | rewrite rdp_list_to_production_opt_correct
                     | step_opt'
                     | t_reduce_list_evar ]. }
      match goal with
        | [ |- appcontext[@rdp_list_to_production] ] => fail 1
        | _ => idtac
      end.
      etransitivity_rev _.
      { step_opt'; [ | reflexivity ].
        step_opt'.
        step_opt'; [ | reflexivity ].
        unfold rdp_list_to_production_opt at 1; simpl.
        change @inner_nth' with @nth' at 3.
        etransitivity_rev _.
        { repeat step_opt'.
          rewrite nth'_nth.
          rewrite_map_nth_rhs; rewrite !map_map; simpl.
          rewrite <- nth'_nth.
          change @nth' with @inner_nth'.
          apply f_equal2; [ | reflexivity ].
          step_opt'; [ | reflexivity ].
          rewrite map_id.
          change @inner_nth' with @nth' at 3.
          rewrite nth'_nth.
          rewrite_map_nth_rhs; simpl.
          rewrite <- nth'_nth.
          change @nth' with @inner_nth'.
          apply f_equal2; [ | reflexivity ].
          reflexivity. }
        (*etransitivity_rev _.
        { change @inner_nth' with @nth' at 1.
          etransitivity_rev _.
          { step_opt'.
            etransitivity_rev _.
            { step_opt'.
              rewrite nth'_nth; reflexivity. }
            match goal with
              | [ |- _ = map (fun x => nth ?n (@?ls x) ?d) ?ls' ]
                => etransitivity_rev (map (fun ls'' => nth n ls'' d) (map ls ls'));
                  [ rewrite !map_map; reflexivity | ]
            end.
            reflexivity. }*)
        reflexivity. }
      reflexivity. }
    etransitivity_rev _.
    { repeat first [ step_opt' | apply (f_equal2 (inner_nth' _)); fin_step_opt ];
      [ | reflexivity | reflexivity | reflexivity | ].
      { t_reduce_list_evar; [ reflexivity | ].
        repeat step_opt'; [ | reflexivity ].
        apply f_equal2; [ | ].
        { step_opt'; [ | reflexivity ].
          t_reduce_fix.
          reflexivity. }
        { match goal with
            | [ |- _ = ?f (?x - ?y) (?pf ?a ?b ?c ?d) ]
              => let f' := fresh in
                 set (f' := f);
                   let ty := constr:(f' (x - y)%natr (@opt_helper_minusr_proof a b c d) = f' (x - y) (pf a b c d )) in
                   refine (_ : ty); change ty;
                   clearbody f'
          end.
          match goal with
            | [ |- ?f ?x ?y = ?f ?x' ?y' ]
              => generalize y; generalize y'
          end.
          rewrite minusr_minus; intros; f_equal.
          apply Le.le_proof_irrelevance. } }
      reflexivity. }
    (** [nth'] is useful when the index is unknown at top-level, but performs poorly in [simpl] when the index is eventually known at compile-time.  So we need to remove the [nth'] *)
    etransitivity_rev _.
    { change @inner_nth' with @nth'.
      step_opt'; [ | reflexivity ].
      apply (f_equal2 (nth' _)); [ | reflexivity ].
      step_opt'; [ | reflexivity ].
      step_opt'.
      step_opt'.
      rewrite nth'_nth; apply (f_equal2 (nth _)); [ | reflexivity ].
      step_opt'; [ | reflexivity ].
      rewrite nth'_nth; apply (f_equal2 (nth _)); [ | reflexivity ].
      step_opt'.
      t_reduce_list_evar; [ reflexivity | ].
      step_opt'.
      step_opt'; [ | reflexivity ].
      rewrite nth'_nth.
      apply (f_equal2 andb); [ reflexivity | ].
      match goal with
        | [ |- _ = ?f ?x ?a ?b ?c ]
          => refine (f_equal (fun x' => f x' a b c) _)
      end.
      fin_step_opt; [ reflexivity | ].
      apply (f_equal2 (nth _)); [ | reflexivity ].
      step_opt'; [ | reflexivity ].
      rewrite nth'_nth; reflexivity. }
    change @nth' with @inner_nth' at 1.
    match goal with
      | [ |- appcontext[@nth'] ] => fail 1
      | _ => change @inner_nth' with @nth'
    end.
    unfold item_rect.
    reflexivity.
  Defined.

  Definition parse_nonterminal_opt
             (str : String)
             (nt : String.string)
  : { b : bool | b = parse_nonterminal str nt }.
  Proof.
    let c := constr:(parse_nonterminal_opt'0 str nt) in
    let h := head c in
    let impl := (eval cbv beta iota zeta delta [h proj1_sig] in (proj1_sig c)) in
    (exists impl);
      abstract (exact (proj2_sig c)).
  Defined.
End recursive_descent_parser.

(** This tactic solves the simple case where the type of string is
    judgmentally [const_data * variable_data], and [take] and [drop]
    judgmentally preserve the constant data. *)

Ltac solve_default_str_carrier :=
  match goal with |- str_carrier _ _ => idtac end;
  eapply str_carrier_default; hnf; simpl;
  let string := match goal with |- { to_string : _ * _ -> ?string * _ & _ } => constr:string end in
  match goal with |- { to_string : _ * _ -> string * _ & _ } => idtac end;
    let T := match goal with |- { to_string : _ * _ -> string * ?T & _ } => constr:T end in
    exists (fun x : string * T => x);
      exists (fun x : string * T => x);
      simpl @fst; simpl @snd;
      solve [ repeat split ].

Hint Extern 1 (str_carrier _ _) => solve_default_str_carrier : typeclass_instances.
