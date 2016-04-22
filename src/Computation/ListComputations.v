Require Import
        Coq.Arith.Arith
        Coq.Sets.Ensembles
        Coq.Lists.List.

Require Import
        Fiat.Common.List.ListFacts
        Fiat.Common.DecideableEnsembles
        Fiat.Computation.

(* Operations on lists using computations. *)

Section ListComprehension.

  Context {A : Type}.

  Definition ListComprehension
             (P : Ensemble A)
    := {l | forall x, List.In x l <-> P x }.

  Definition FilteredList
             (xs : list A)
             (P : Ensemble A)             
    := ListComprehension (fun x => List.In x xs /\ P x).

  Definition build_FilteredList
             (xs : list A)
             (P : Ensemble A)
    : Comp (list A)
    := fold_right (fun (a : A) (l : Comp (list A)) =>
                     l' <- l;
                     b <- { b | decides b (P a) };
                     if b
                     then ret (a :: l')
                     else ret l'
                  ) (ret nil) xs.

  Definition refine_ListComprehension_filtered_list
    : forall (P : Ensemble A)
             (xs : list A),
      refine (FilteredList xs P)
             (build_FilteredList xs P).
  Proof.
    unfold FilteredList, ListComprehension; induction xs; simpl; intros.
    - refine pick val _; try reflexivity; intuition.
    - rewrite <- IHxs.
      unfold refine; intros; computes_to_inv.
      destruct v1; simpl in *; computes_to_inv;
        subst; computes_to_econstructor; simpl;
          setoid_rewrite H; intuition.
      + subst; eauto.
      + subst; intuition.
  Qed.

  Lemma refine_filtered_list
    : forall (xs : list A)
             (P : Ensemble A)
             (P_dec : DecideableEnsemble P),
      refine (build_FilteredList xs P)
             (ret (filter dec xs)).
  Proof.
    unfold build_FilteredList; induction xs; intros.
    - reflexivity.
    - simpl; setoid_rewrite IHxs.
      simplify with monad laws.
      destruct (dec a) eqn: eq_dec_a;
        [ setoid_rewrite dec_decides_P in eq_dec_a; refine pick val true |
          setoid_rewrite Decides_false in eq_dec_a; refine pick val false ];
        auto; simplify with monad laws; reflexivity.
  Qed.

End ListComprehension.

Notation "⟦ x 'in' xs | P ⟧" :=
  (FilteredList xs (fun x => P)) : comp_scope.

Section UpperBound.

  Context {A : Type}.
  Variable op : A -> A -> Prop.

  Definition UpperBound
             (rs : list A)
             (r : A) :=
    forall r' : A, List.In r' rs -> op r r'.

  Definition SingletonSet (P : Ensemble A) :=
    {b' | forall b : A, b' = Some b <-> P b}.

  Definition ArgMax
             {B}
             (f : B -> A)
    : Ensemble B :=
    fun b => forall b', op (f b') (f b).

  Definition MaxElements
             (elements : Comp (list A))
    := elements' <- elements;
         ⟦ element in elements' | UpperBound elements' element ⟧.

  Definition find_UpperBound (f : A -> nat) (ns : list A) : list A :=
    let max := fold_right
                 (fun n acc => max (f n) acc) O ns in
    filter (fun n => NPeano.leb max (f n)) ns.

  Lemma find_UpperBound_highest_length
    : forall (f : A -> nat) ns n,
      List.In n (find_UpperBound f ns) -> forall n', List.In n' ns -> (f n) >= (f n').
  Proof.
    unfold ge, find_UpperBound; intros.
    apply filter_In in H; destruct H; apply NPeano.leb_le in H1.
    rewrite <- H1; clear H1 H n.
    apply fold_right_max_is_max; auto.
  Qed.

End UpperBound.

Instance DecideableEnsembleUpperBound {A}
         (f : A -> nat)
         (ns : list A)
  : DecideableEnsemble (UpperBound (fun a a' => f a >= f a') ns) :=
  {| dec n := NPeano.leb (fold_right (fun n acc => max (f n) acc) O ns) (f n) |}.
Proof.
  unfold UpperBound, ge; intros; rewrite NPeano.leb_le; intuition.
  - remember (f a); clear Heqn; subst; eapply le_trans;
      [ apply fold_right_max_is_max; apply H0 | assumption ].
  - eapply fold_right_higher_is_higher; eauto.
Defined.

Corollary refine_find_UpperBound {A}
  : forall (f : A -> nat) ns,
    refine (⟦ n in ns | UpperBound (fun a a' => f a >= f a') ns n ⟧)
           (ret (find_UpperBound f ns)).
Proof.
  intros.
  setoid_rewrite refine_ListComprehension_filtered_list.
  setoid_rewrite refine_filtered_list with (P_dec := DecideableEnsembleUpperBound f ns).
  reflexivity.
Qed.
