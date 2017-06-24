Require Import
        Coq.Strings.String
        Coq.Arith.Mult
        Coq.Vectors.Vector.

Require Import
        Fiat.Examples.DnsServer.SimplePacket
        Fiat.Common.SumType
        Fiat.Common.BoundedLookup
        Fiat.Common.ilist
        Fiat.Common.DecideableEnsembles
        Fiat.Computation
        Fiat.QueryStructure.Specification.Representation.Notations
        Fiat.QueryStructure.Specification.Representation.Heading
        Fiat.QueryStructure.Specification.Representation.Tuple
        Fiat.BinEncoders.Env.BinLib.AlignedByteString
        Fiat.BinEncoders.Env.BinLib.AlignWord
        Fiat.BinEncoders.Env.Common.Specs
        Fiat.BinEncoders.Env.Common.Compose
        Fiat.BinEncoders.Env.Common.ComposeOpt
        Fiat.BinEncoders.Env.Automation.Solver
        Fiat.BinEncoders.Env.Lib2.WordOpt
        Fiat.BinEncoders.Env.Lib2.NatOpt
        Fiat.BinEncoders.Env.Lib2.StringOpt
        Fiat.BinEncoders.Env.Lib2.EnumOpt
        Fiat.BinEncoders.Env.Lib2.FixListOpt
        Fiat.BinEncoders.Env.Lib2.SumTypeOpt
        Fiat.BinEncoders.Env.Lib2.DomainNameOpt
        Fiat.Common.IterateBoundedIndex
        Fiat.Common.Tactics.CacheStringConstant.

Require Import
        Bedrock.Word.

Section AlignedDecoders.

  Context {cache : Cache}.
  Context {cacheAddNat : CacheAdd cache nat}.

  Lemma aligned_encode_char_eq
    : forall (w : word 8) cd,
      refine (encode_word_Spec (transformerUnit := ByteString_QueueTransformerOpt) w cd)
             (ret (build_aligned_ByteString (Vector.cons _ w _ (Vector.nil _)), addE cd 8)).
    Proof.
      intros; shatter_word w; simpl.
      unfold encode_word_Spec; simpl.
      compute.
      intros.
      computes_to_inv; subst.
      match goal with
        |- computes_to (ret ?c) ?v => replace c with v
      end.
      computes_to_econstructor.
      f_equal.
      eapply ByteString_f_equal; simpl.
      instantiate (1 := eq_refl _).
      rewrite <- !Eqdep_dec.eq_rect_eq_dec; eauto using Peano_dec.eq_nat_dec.
      erewrite eq_rect_Vector_cons; repeat f_equal.
      instantiate (1 := eq_refl _); reflexivity.
      Grab Existential Variables.
      reflexivity.
    Qed.

    Lemma AlignedDecodeChar {C}
        {numBytes}
    : forall (v : Vector.t (word 8) (S numBytes))
             (t : (word 8 * ByteString * CacheDecode) -> C)
             (e : C)
             cd,
      Ifopt (decode_word
               (transformerUnit := ByteString_QueueTransformerOpt) (sz := 8) (build_aligned_ByteString v) cd)
            as w Then t w Else e
            =
       LetIn (Vector.nth v Fin.F1)
             (fun w => t (w, build_aligned_ByteString (snd (Vector_split 1 _ v)), addD cd 8)).
  Proof.
    unfold LetIn; intros.
    unfold decode_word, WordOpt.decode_word.
    rewrite aligned_decode_char_eq; simpl.
    f_equal.
    pattern numBytes, v; apply Vector.caseS; simpl; intros.
    reflexivity.
  Qed.

  Lemma AlignedEncodeChar {numBytes}
    : forall (w : word 8) ce ce' (c : _ -> Comp _) (v : Vector.t _ numBytes),
      refine (c (addE ce 8)) (ret (build_aligned_ByteString v, ce'))
      -> refine (((encode_word_Spec (transformerUnit := ByteString_QueueTransformerOpt) w)
                   ThenC c) ce)
                (ret (build_aligned_ByteString (Vector.cons _ w _ v), ce')).
  Proof.
    unfold compose; intros.
    unfold Bind2.
    setoid_rewrite aligned_encode_char_eq; simplify with monad laws.
    simpl; rewrite H; simplify with monad laws.

    simpl.
    rewrite <- build_aligned_ByteString_append.
    reflexivity.
  Qed.

  Lemma AlignedDecode2Char {C}
        {numBytes}
    : forall (v : Vector.t (word 8) (S (S numBytes)))
             (t : (word 16 * ByteString * CacheDecode) -> C)
             (e : C)
             cd,
      Ifopt (decode_word
               (transformerUnit := ByteString_QueueTransformerOpt) (sz := 16) (build_aligned_ByteString v) cd) as w
      Then t w Else e=
      Let n := Core.append_word (Vector.nth v (Fin.FS Fin.F1)) (Vector.nth v Fin.F1) in
        t (n, build_aligned_ByteString (snd (Vector_split 2 _ v)), addD cd 16).
  Proof.
    unfold LetIn; intros.
    unfold decode_word, WordOpt.decode_word.
    match goal with
      |- context[Ifopt ?Z as _ Then _ Else _] => replace Z with
                                                 (let (v', v'') := Vector_split 2 numBytes v in Some (VectorByteToWord v', build_aligned_ByteString v'')) by (symmetry; apply (@aligned_decode_char_eq' _ 1 v))
    end.
    unfold Vector_split, If_Opt_Then_Else, If_Opt_Then_Else.
    f_equal.
    rewrite !Vector_nth_tl, !Vector_nth_hd.
    erewrite VectorByteToWord_cons.
    rewrite <- !Eqdep_dec.eq_rect_eq_dec; eauto using Peano_dec.eq_nat_dec.
    f_equal.
    erewrite VectorByteToWord_cons.
    rewrite <- !Eqdep_dec.eq_rect_eq_dec; eauto using Peano_dec.eq_nat_dec.
    Grab Existential Variables.
    omega.
    omega.
  Qed.

  Variable addE_addE_plus :
    forall (ce : CacheEncode) (n m : nat), addE (addE ce n) m = addE ce (n + m).

  Lemma encode_words {n m}
    : forall (w : word (n + m)) ce,
      refine (encode_word_Spec (transformerUnit := ByteString_QueueTransformerOpt) w ce)
             ((encode_word_Spec (transformerUnit := ByteString_QueueTransformerOpt) (split1' _ _ w)
              ThenC (encode_word_Spec (transformerUnit := ByteString_QueueTransformerOpt) (split2' _ _ w)))
              ce).
  Proof.
    induction n.
    - unfold compose; simpl; intros.
      unfold encode_word_Spec at 2; simpl.
      autorewrite with monad laws.
      simpl; rewrite addE_addE_plus.
      pose proof transform_id_left as H'; simpl in H'; rewrite H'.
      reflexivity.
    - simpl; intros.
      rewrite (word_split_SW w) at 1.
      rewrite encode_SW_word.
      unfold compose, Bind2.
      rewrite (IHn (word_split_tl w) (addE ce 1)).
      unfold compose, Bind2.
      unfold encode_word_Spec; autorewrite with monad laws.
      simpl.
      rewrite encode_word_S.
      pose proof transform_assoc as H'; simpl in H'.
      rewrite !H'.
      rewrite !addE_addE_plus; simpl.
      f_equiv.
      f_equiv.
      f_equiv.
      rewrite !word_split_hd_SW_word, !word_split_tl_SW_word.
      fold plus.
      clear;
        generalize (split1' n m (word_split_tl w))
                   (ByteString_enqueue (word_split_hd w) ByteString_id).
      induction w0; simpl in *.
      + intros; pose proof (transform_id_right b) as H; simpl in H; rewrite H; eauto.
      + intros.
        rewrite <- (IHw0 (wtl w) b0).
        pose proof enqueue_transform_opt as H'''; simpl in H'''.
        rewrite <- H'''; eauto.
      + eauto.
  Qed.

  Lemma AlignedEncode2Char {numBytes}
    : forall (w : word 16) ce ce' (c : _ -> Comp _) (v : Vector.t _ numBytes),
      refine (c (addE ce 16)) (ret (build_aligned_ByteString v, ce'))
      -> refine (((encode_word_Spec (transformerUnit := ByteString_QueueTransformerOpt) w)
                   ThenC c) ce)
                (ret (build_aligned_ByteString (Vector.cons
                                                  _ (split1' 8 8 w) _
                                                  (Vector.cons _ (split2' 8 8 w) _ v)), ce')).
  Proof.
    unfold compose, Bind2; intros.
    intros; setoid_rewrite (@encode_words 8 8 w).
    rewrite (@AlignedEncodeChar 1) by apply aligned_encode_char_eq.
    simplify with monad laws.
    unfold snd.
    rewrite addE_addE_plus.
    rewrite H.
    simplify with monad laws.
    unfold fst.
    rewrite <- build_aligned_ByteString_append.
    unfold append.
    reflexivity.
  Qed.


  Lemma BindOpt_assoc {A A' A''} :
    forall (a_opt : option A)
           (f : A -> option A')
           (g : A' -> option A''),
    BindOpt (BindOpt a_opt f) g =
    BindOpt a_opt (fun a => BindOpt (f a) g).
  Proof.
    destruct a_opt as [ ? | ]; simpl; intros; eauto.
  Qed.

  Corollary AlignedDecode2Nat {C}
            {numBytes}
    : forall (v : Vector.t (word 8) (S (S numBytes)))
             (t : _ -> C)
             e
             cd,
    Ifopt (decode_nat (transformerUnit := ByteString_QueueTransformerOpt) 16 (build_aligned_ByteString v) cd) as w
    Then t w Else e
     =
      Let n := wordToNat (Core.append_word (Vector.nth v (Fin.FS Fin.F1)) (Vector.nth v Fin.F1)) in
        t (n, build_aligned_ByteString (snd (Vector_split 2 _ v)), addD cd 16).
  Proof.
    unfold CacheDecode.
    unfold decode_nat, DecodeBindOpt2; intros.
    unfold BindOpt at 1.
    rewrite AlignedDecode2Char.
    reflexivity.
  Qed.

  Corollary AlignedEncode2Nat
            {numBytes}
    : forall (n : nat) ce ce' (c : _ -> Comp _) (v : Vector.t _ numBytes),
      refine (c (addE ce 16)) (ret (build_aligned_ByteString v, ce'))
      -> refine (((encode_nat_Spec 16 (transformerUnit := ByteString_QueueTransformerOpt) n)
                    ThenC c) ce)
                (ret (build_aligned_ByteString (Vector.cons
                                                  _ (split1' 8 8 (natToWord 16 n)) _
                                                  (Vector.cons _ (split2' 8 8 (natToWord 16 n)) _ v)), ce')).
  Proof.
    unfold encode_nat_Spec; cbv beta; intros.
    rewrite <- AlignedEncode2Char; eauto.
    reflexivity.
  Qed.

  Lemma optimize_under_if_opt {A ResultT}
    : forall (a_opt : option A) (t t' : A -> ResultT) (e e' : ResultT),
      (forall a, t a = t' a) -> e = e' ->
      Ifopt a_opt as a Then t a Else e = Ifopt a_opt as a Then t' a Else e'.
  Proof.
    intros; subst; eauto.
    destruct a_opt; eauto.
  Qed.

  Lemma rewrite_under_LetIn
        {A B}
    : forall (a : A) (k k' : A -> B),
      (forall a, k a = k' a) -> LetIn a k = LetIn a k'.
  Proof.
    intros; unfold LetIn; eauto.
  Qed.

  Fixpoint Guarded_Vector_split
           (sz n : nat)
           {struct sz}
    : Vector.t (word 8) n
      -> Vector.t (word 8) (sz + (n - sz)) :=
    match sz, n return
          Vector.t _ n
          -> Vector.t (word 8) (sz + (n - sz))
    with
    | 0, _ => fun v => (eq_rect _ (Vector.t _) v _ (minus_n_O n))
    | S n', 0 =>
      fun v =>
        Vector.cons _ (wzero _) _ (Guarded_Vector_split n' _ v)
    | S n', S sz' =>
      fun v =>
        Vector.cons _ (Vector.hd v) _ (Guarded_Vector_split n' _ (Vector.tl v))
    end .

  Lemma le_B_Guarded_Vector_split
        {n}
        (b : Vector.t _ n)
        (m : nat)
    : {b' : ByteString | le_B b' (build_aligned_ByteString b)}.
    eexists (build_aligned_ByteString
               (snd (Vector_split _ _ (Guarded_Vector_split m n b)))).
    abstract (unfold build_aligned_ByteString, le_B; simpl; omega).
  Defined.

  Lemma build_aligned_ByteString_eq_split
    : forall m n b H0,
      (m <= n)%nat
      -> build_aligned_ByteString b =
         (build_aligned_ByteString (eq_rect (m + (n - m)) (t (word 8)) (Guarded_Vector_split m n b) n H0)).
  Proof.
    intros.
    intros; eapply ByteString_f_equal; simpl.
    instantiate (1 := eq_refl _); reflexivity.
    instantiate (1 := eq_refl _).
    simpl.
    revert n b H0 H; induction m; simpl.
    intros ? ?; generalize (minus_n_O n).
    intros; rewrite <- Equality.transport_pp.
    apply Eqdep_dec.eq_rect_eq_dec; auto with arith.
    intros.
    inversion H; subst.
    - revert b H0 IHm; clear.
      intro; pattern m, b; apply Vector.caseS; simpl; intros.
      assert ((n + (n - n)) = n) by omega.
      rewrite eq_rect_Vector_cons with (H' := H).
      f_equal.
      erewrite <- IHm; eauto.
    - revert b H0 IHm H1; clear.
      intro; pattern m0, b; apply Vector.caseS; simpl; intros.
      assert ((m + (n - m)) = n) by omega.
      erewrite eq_rect_Vector_cons with (H' := H).
      f_equal.
      erewrite <- IHm; eauto.
      omega.
  Qed.

  Lemma ByteAlign_Decode_w_Measure_le {A}
    : forall (dec_a : ByteString -> CacheDecode -> option (A * ByteString * CacheDecode))
             (n m : nat)
             (dec_a' : Vector.t (word 8) (m + (n - m)) -> A)
             (cd : CacheDecode)
             (f : CacheDecode -> CacheDecode)
             (b : Vector.t (word 8) n)
             decode_a_le
             (dec_fail : ~ (m <= n)%nat
                         -> forall b cd, dec_a (build_aligned_ByteString (numBytes := n) b) cd = None),
      (forall b cd, dec_a (build_aligned_ByteString b) cd =
                    Some (dec_a' b, build_aligned_ByteString (snd (Vector_split m (n - m) b)), f cd))
      -> Decode_w_Measure_le dec_a (build_aligned_ByteString b) cd decode_a_le =
         match Compare_dec.le_dec m n with
         | left e => (Let a := dec_a' (Guarded_Vector_split m n b) in
                          Some (a, le_B_Guarded_Vector_split b m, f cd))
         | right _ => None
         end.
  Proof.
    intros.
    destruct (Compare_dec.le_dec m n).
    assert (m + (n - m) = n) by omega.
    assert (forall b, Decode_w_Measure_le dec_a (build_aligned_ByteString b) cd decode_a_le
                      = Decode_w_Measure_le dec_a (build_aligned_ByteString ( eq_rect _ _ (Guarded_Vector_split m n b) _ H0)) cd decode_a_le).
    { revert l; clear; intros.
      destruct (Decode_w_Measure_le dec_a (build_aligned_ByteString b) cd decode_a_le)
        as [ [ [? [? ?] ] ?] | ] eqn: ?.
      apply Decode_w_Measure_le_eq' in Heqo.
      simpl in Heqo.
      destruct (Decode_w_Measure_le dec_a
                                    (build_aligned_ByteString (eq_rect (m + (n - m)) (t (word 8)) (Guarded_Vector_split m n b) n H0)) cd decode_a_le) as [ [ [? [? ?] ] ?] | ] eqn: ?.
      apply Decode_w_Measure_le_eq' in Heqo0.
      simpl in *.
      rewrite <- build_aligned_ByteString_eq_split in Heqo0 by eauto.
      rewrite Heqo0 in Heqo.
      injection Heqo; intros.
      rewrite H, H2;
        repeat f_equal.
      revert l0 l1. rewrite H1; intros; f_equal.
      f_equal; apply Core.le_uniqueness_proof.
      apply ByteString_id.
      eapply Decode_w_Measure_le_eq'' in Heqo0.
      rewrite <- build_aligned_ByteString_eq_split in Heqo0 by eauto.
      rewrite Heqo0 in Heqo.
      discriminate.
      apply ByteString_id.
      erewrite build_aligned_ByteString_eq_split in Heqo by eauto.
      rewrite Heqo; reflexivity.
    }
    rewrite H1.
    match goal with
      |- ?a = _ => destruct a as [ [ [? ?] ? ] | ] eqn: ?
    end.
    eapply Decode_w_Measure_le_eq' in Heqo.
    assert (dec_a (build_aligned_ByteString (Guarded_Vector_split m n b)) cd
            = Some (a, projT1 s, c)).
    { destruct s; simpl in *.
      rewrite <- Heqo.
      unfold build_aligned_ByteString; repeat f_equal; simpl.
      eapply ByteString_f_equal; simpl.
      instantiate (1 := eq_refl _); reflexivity.
      instantiate (1 := sym_eq H0).
      clear H1.
      destruct H0; reflexivity.
    }
    rewrite H in H2; injection H2; intros.
    rewrite H3, H5; unfold LetIn; simpl.
    repeat f_equal.
    destruct s; simpl in *.
    unfold le_B_Guarded_Vector_split; simpl.
    clear H1; revert l0.
    rewrite <- H4; intros.
    f_equal; apply Core.le_uniqueness_proof.
    apply ByteString_id.
    apply Decode_w_Measure_le_eq'' in Heqo.
    pose proof (H (Guarded_Vector_split m n b) cd).
    assert (Some (dec_a' (Guarded_Vector_split m n b),
                  build_aligned_ByteString (snd (Vector_split m (n - m) (Guarded_Vector_split m n b))),
                  f cd) = None).
    { rewrite <- Heqo.
      rewrite <- H.
      repeat f_equal.
      eapply ByteString_f_equal; simpl.
      instantiate (1 := eq_refl _); reflexivity.
      instantiate (1 := sym_eq H0).
      clear H1.
      destruct H0; reflexivity.
    }
    discriminate.
    eapply dec_fail in n0; simpl.
    eapply Specs.Decode_w_Measure_le_eq' in n0.
    apply n0.
  Qed.

  Lemma If_Opt_Then_Else_BindOpt {A B C}
    : forall (a_opt : option A)
             (t : A -> option B)
             (e : option B)
             (k : _ -> option C),
        BindOpt (Ifopt a_opt as a Then t a Else e) k
        = Ifopt a_opt as a Then (BindOpt (t a) k) Else (BindOpt e k).
  Proof.
    destruct a_opt; simpl; intros; reflexivity.
  Qed.

  Lemma lt_B_Guarded_Vector_split
        {n}
        (b : Vector.t _ n)
        (m : nat)
        (m_OK : lt 0 m)
        (_ : ~ lt n m)
    : {b' : ByteString | lt_B b' (build_aligned_ByteString b)}.
    eexists (build_aligned_ByteString
               (snd (Vector_split _ _ (Guarded_Vector_split m n b)))).
    abstract (unfold build_aligned_ByteString, lt_B; simpl; omega).
  Defined.

  Fixpoint BytesToString {sz}
           (b : Vector.t (word 8) sz)
    : string :=
    match b with
    | Vector.nil => EmptyString
    | Vector.cons a _ b' => String (Ascii.ascii_of_N (wordToN a)) (BytesToString b')
    end.

  Variable addD_addD_plus :
    forall (cd : CacheDecode) (n m : nat), addD (addD cd n) m = addD cd (n + m).

  Lemma decode_string_aligned_ByteString
        {sz sz'}
    : forall (b : t (word 8) (sz + sz'))
             (cd : CacheDecode),
      FixStringOpt.decode_string sz (build_aligned_ByteString b) cd =
      Some (BytesToString (fst (Vector_split sz sz' b)),
            build_aligned_ByteString (snd (Vector_split sz sz' b)),
            addD cd (8 * sz)).
  Proof.
    induction sz; intros.
    - simpl; repeat f_equal.
    - simpl.
      assert (forall A n b, exists a b', b = Vector.cons A a n b')
        by (clear; intros; pattern n, b; apply caseS; eauto).
      destruct (H _ _ b) as [? [? ?] ]; subst; simpl.
      unfold AsciiOpt.decode_ascii, DecodeBindOpt2.
      rewrite BindOpt_assoc; simpl.
      etransitivity.
      unfold BindOpt at 1.
      rewrite AlignedDecodeChar; simpl.
      rewrite IHsz. higher_order_reflexivity.
      simpl.
      destruct (Vector_split sz sz' x0); simpl.
      unfold LetIn.
      rewrite addD_addD_plus;
        repeat f_equal.
      omega.
  Qed.

  Fixpoint StringToBytes
           (s : string)
    : Vector.t (word 8) (String.length s) :=
    match s return Vector.t (word 8) (String.length s) with
    | EmptyString => Vector.nil _
    | String a s' => Vector.cons _ (NToWord 8 (Ascii.N_of_ascii a)) _ (StringToBytes s')
    end.

  Lemma encode_string_ByteString
    : forall (s : string)
             (ce : CacheEncode),
      refine (FixStringOpt.encode_string_Spec s ce)
             (ret (build_aligned_ByteString (StringToBytes s), addE ce (8 * String.length s))).
  Proof.
    induction s; intros; simpl.
    - f_equiv. f_equal.
      eapply ByteString_f_equal.
      instantiate (1 := eq_refl _); reflexivity.
      instantiate (1 := eq_refl _); reflexivity.
    - unfold AsciiOpt.encode_ascii_Spec.
      unfold Bind2;  setoid_rewrite aligned_encode_char_eq.
      simplify with monad laws.
      rewrite IHs.
      simplify with monad laws.
      simpl.
      rewrite <- build_aligned_ByteString_append; simpl.
      rewrite !addE_addE_plus.
      f_equiv; f_equiv; f_equiv; omega.
  Qed.

  Lemma encode_string_aligned_ByteString {numBytes}
    : forall (s : string)
             (ce : CacheEncode)
             (ce' : CacheEncode)
             (c : _ -> Comp _) (v : Vector.t _ numBytes),
      refine (c (addE ce (8 * String.length s))) (ret (build_aligned_ByteString v, ce'))
      -> refine (((FixStringOpt.encode_string_Spec s) ThenC c) ce)
                (ret (build_aligned_ByteString (append (StringToBytes s) v), ce')).
  Proof.
    unfold compose, Bind2; autorewrite with monad laws; intros.
    rewrite encode_string_ByteString.
    simplify with monad laws.
    unfold snd at 1.
    rewrite H.
    simplify with monad laws.
    simpl.
    rewrite <- build_aligned_ByteString_append; simpl.
    reflexivity.
  Qed.

  Lemma decode_string_aligned_ByteString_overflow
        {sz}
    : forall {sz'}
             (b : t (word 8) sz')
             (cd : CacheDecode),
      lt sz' sz
      -> FixStringOpt.decode_string sz (build_aligned_ByteString b) cd = None.
  Proof.
    induction sz; intros.
    - omega.
    - simpl.
      assert (forall A n b, exists a b', b = Vector.cons A a n b')
        by (clear; intros; pattern n, b; apply caseS; eauto).
      destruct sz'.
      + reflexivity.
      + destruct (H0 _ _ b) as [? [? ?] ]; subst; simpl.
        unfold AsciiOpt.decode_ascii, DecodeBindOpt2.
        rewrite BindOpt_assoc; simpl.
        etransitivity.
        unfold BindOpt.
        rewrite AlignedDecodeChar; simpl.
        rewrite IHsz. higher_order_reflexivity.
        omega.
        reflexivity.
  Qed.

  Lemma ByteAlign_Decode_w_Measure_lt {A}
    : forall (dec_a : nat -> ByteString -> CacheDecode -> option (A * ByteString * CacheDecode))
             (n m : nat)
             (dec_a' : forall m n, Vector.t (word 8) (m + n) -> A)
             (cd : CacheDecode)
             (f : nat -> CacheDecode -> CacheDecode)
             (b : Vector.t (word 8) n)
             (m_OK : lt 0 m)
             decode_a_le
             (dec_fail : (lt n m)%nat
                         -> forall b cd, dec_a m (build_aligned_ByteString (numBytes := n) b) cd = None),
      (forall n m b cd, dec_a m (build_aligned_ByteString b) cd =
                        Some (dec_a' _ _ b, build_aligned_ByteString (snd (Vector_split m n b)), f m cd))
      -> Decode_w_Measure_lt (dec_a m) (build_aligned_ByteString b) cd decode_a_le =
         match Compare_dec.lt_dec n m with
         | left _ => None
         | right n' => (Let a := dec_a' _ _ (Guarded_Vector_split m n b) in
                            Some (a, lt_B_Guarded_Vector_split b m m_OK n' , f m cd))
         end.
  Proof.
    intros.
    destruct (Compare_dec.lt_dec m n);
      destruct (Compare_dec.lt_dec n m); try omega.
    - assert (m + (n - m) = n) by omega.
      assert (forall b, Decode_w_Measure_lt (dec_a m) (build_aligned_ByteString b) cd decode_a_le
                        = Decode_w_Measure_lt (dec_a m)(build_aligned_ByteString ( eq_rect _ _ (Guarded_Vector_split m n b) _ H0)) cd decode_a_le).
      { revert l; clear; intros.
        destruct (Decode_w_Measure_lt (dec_a m) (build_aligned_ByteString b) cd decode_a_le)
          as [ [ [? [? ?] ] ?] | ] eqn: ?.
        apply Decode_w_Measure_lt_eq' in Heqo.
        simpl in Heqo.
        destruct (Decode_w_Measure_lt (dec_a m)
                                      (build_aligned_ByteString (eq_rect _ (t (word 8)) (Guarded_Vector_split m n b) n H0)) cd decode_a_le) as [ [ [? [? ?] ] ?] | ] eqn: ?.
        apply Decode_w_Measure_lt_eq' in Heqo0.
        unfold proj1_sig in Heqo0.
        rewrite <- build_aligned_ByteString_eq_split in Heqo0.
        rewrite Heqo0 in Heqo.
        injection Heqo; intros.
        rewrite H, H2;
          repeat f_equal.
        revert l1 l0. rewrite H1; intros; f_equal.
        f_equal; apply Core.le_uniqueness_proof.
        omega.
        apply ByteString_id.
        eapply Decode_w_Measure_lt_eq'' in Heqo0.
        rewrite <- build_aligned_ByteString_eq_split in Heqo0 by omega.
        rewrite Heqo0 in Heqo.
        discriminate.
        apply ByteString_id.
        erewrite (build_aligned_ByteString_eq_split m n) in Heqo by omega.
        rewrite Heqo; reflexivity.
      }
      rewrite H1.
      match goal with
        |- ?a = _ => destruct a as [ [ [? ?] ? ] | ] eqn: ?
      end.
      eapply Decode_w_Measure_lt_eq' in Heqo.
      assert (dec_a m (build_aligned_ByteString (Guarded_Vector_split m n b)) cd
              = Some (a, projT1 s, c)).
      { destruct s; simpl in *.
        rewrite <- Heqo.
        unfold build_aligned_ByteString; repeat f_equal; simpl.
        eapply ByteString_f_equal; simpl.
        instantiate (1 := eq_refl _); reflexivity.
        instantiate (1 := sym_eq H0).
        clear H1.
        destruct H0; reflexivity.
      }
      rewrite H in H2; injection H2; intros.
      rewrite H3, H5; unfold LetIn; simpl.
      repeat f_equal.
      destruct s; simpl in *.
      unfold lt_B_Guarded_Vector_split; simpl.
      clear H1; revert l0.
      rewrite <- H4; intros.
      f_equal. apply Core.le_uniqueness_proof.
      apply ByteString_id.
      apply Decode_w_Measure_lt_eq'' in Heqo.
      pose proof (H _ _ (Guarded_Vector_split m n b) cd).
      assert (Some (dec_a' _ _ (Guarded_Vector_split m n b),
                    build_aligned_ByteString (snd (Vector_split m (n - m) (Guarded_Vector_split m n b))),
                    f m cd) = None).
      { rewrite <- Heqo.
        rewrite <- H.
        repeat f_equal.
        eapply ByteString_f_equal; simpl.
        instantiate (1 := eq_refl _); reflexivity.
        instantiate (1 := sym_eq H0).
        clear H1.
        destruct H0; reflexivity.
      }
      discriminate.
    - eapply dec_fail in l; simpl.
      eapply Specs.Decode_w_Measure_lt_eq' in l.
      apply l.
    - assert (m = n) by omega; subst.
      assert (n + (n - n) = n) by omega.
      assert (forall b, Decode_w_Measure_lt (dec_a n) (build_aligned_ByteString b) cd decode_a_le
                        = Decode_w_Measure_lt (dec_a n)(build_aligned_ByteString ( eq_rect _ _ (Guarded_Vector_split n n b) _ H0)) cd decode_a_le).
      { clear; intros.
        destruct (Decode_w_Measure_lt (dec_a n) (build_aligned_ByteString b) cd decode_a_le)
          as [ [ [? [? ?] ] ?] | ] eqn: ?.
        apply Decode_w_Measure_lt_eq' in Heqo.
        simpl in Heqo.
        destruct (Decode_w_Measure_lt (dec_a n)
                                      (build_aligned_ByteString (eq_rect _ (t (word 8)) (Guarded_Vector_split n n b) n H0)) cd decode_a_le) as [ [ [? [? ?] ] ?] | ] eqn: ?.
        apply Decode_w_Measure_lt_eq' in Heqo0.
        unfold proj1_sig in Heqo0.
        rewrite <- build_aligned_ByteString_eq_split in Heqo0.
        rewrite Heqo0 in Heqo.
        injection Heqo; intros.
        rewrite H, H2;
          repeat f_equal.
        revert l l0. rewrite H1; intros; f_equal.
        f_equal; apply Core.le_uniqueness_proof.
        omega.
        apply ByteString_id.
        eapply Decode_w_Measure_lt_eq'' in Heqo0.
        rewrite <- build_aligned_ByteString_eq_split in Heqo0 by omega.
        rewrite Heqo0 in Heqo.
        discriminate.
        apply ByteString_id.
        erewrite (build_aligned_ByteString_eq_split n n) in Heqo by omega.
        rewrite Heqo; reflexivity.
      }
      rewrite H1.
      match goal with
        |- ?a = _ => destruct a as [ [ [? ?] ? ] | ] eqn: ?
      end.
      eapply Decode_w_Measure_lt_eq' in Heqo.
      assert (dec_a n (build_aligned_ByteString (Guarded_Vector_split n n b)) cd
              = Some (a, projT1 s, c)).
      { destruct s; simpl in *.
        rewrite <- Heqo.
        unfold build_aligned_ByteString; repeat f_equal; simpl.
        eapply ByteString_f_equal; simpl.
        instantiate (1 := eq_refl _); reflexivity.
        instantiate (1 := sym_eq H0).
        clear H1.
        destruct H0; reflexivity.
      }
      rewrite H in H2; injection H2; intros.
      rewrite H3, H5; unfold LetIn; simpl.
      repeat f_equal.
      destruct s; simpl in *.
      unfold lt_B_Guarded_Vector_split; simpl.
      clear H1; revert l.
      rewrite <- H4; intros.
      f_equal. apply Core.le_uniqueness_proof.
      apply ByteString_id.
      apply Decode_w_Measure_lt_eq'' in Heqo.
      pose proof (H _ _ (Guarded_Vector_split n n b) cd).
      assert (Some (dec_a' _ _ (Guarded_Vector_split n n b),
                    build_aligned_ByteString (snd (Vector_split n (n - n) (Guarded_Vector_split n n b))),
                    f n cd) = None).
      { rewrite <- Heqo.
        rewrite <- H.
        repeat f_equal.
        eapply ByteString_f_equal; simpl.
        instantiate (1 := eq_refl _); reflexivity.
        instantiate (1 := sym_eq H0).
        clear H1.
        destruct H0; reflexivity.
      }
      discriminate.
  Qed.

  Lemma optimize_under_match {A B} {P}
    : forall (a a' : A) (f : {P a a'} + {~P a a'}) (t t' : _ -> B)
             (e e' : _ -> B),
      (forall (a a' : A) (a_eq : _), t a_eq = t' a_eq)
      -> (forall (a a' : A) (a_neq : _), e a_neq = e' a_neq)
      -> match f with
         | left e => t e
         | right n => e n
         end =
         match f with
         | left e => t' e
         | right n => e' n
         end.
  Proof.
    destruct f; simpl; intros; eauto.
  Qed.

  Lemma optimize_Fix {A}
    : forall
      (body : forall x : ByteString,
          (forall y : ByteString,
              lt_B y x -> (fun _ : ByteString => CacheDecode -> option (A * ByteString * CacheDecode)) y) ->
          (fun _ : ByteString => CacheDecode -> option (A * ByteString * CacheDecode)) x)
      (body' : forall x : nat,
          (forall y : nat,
              (lt y x)%nat ->
              (fun m : nat =>
                 t (word 8) m -> CacheDecode ->
                 option (A * {n : _ & Vector.t _ n} * CacheDecode)) y) ->
          t (word 8) x -> CacheDecode -> option (A * {n : _ & Vector.t _ n} * CacheDecode) )
      n (b : Vector.t _ n) (cd : CacheDecode)
      (body_Proper :
         forall (x0 : ByteString)
                (f g : forall y : ByteString, lt_B y x0 -> CacheDecode -> option (A * ByteString * CacheDecode)),
           (forall (y : ByteString) (p : lt_B y x0), f y p = g y p) -> body x0 f = body x0 g)
      (body'_Proper :
         forall (x0 : nat)
                (f
                   g : forall y : nat,
                    (lt y x0)%nat -> t (word 8) y -> CacheDecode -> option (A * {n0 : nat & t Core.char n0} * CacheDecode)),
           (forall (y : nat) (p : (lt y x0)%nat), f y p = g y p) -> body' x0 f = body' x0 g)
    ,
      (forall n (b : Vector.t (word 8) n)
              (rec : forall x : ByteString,
                  lt_B x (build_aligned_ByteString b) -> CacheDecode -> option (A * ByteString * CacheDecode))
              (rec' : forall x : nat,
                  (lt x n)%nat -> t Core.char x -> CacheDecode ->
                  option (A * {n : _ & Vector.t _ n} * CacheDecode))
              cd,
          (forall m cd b a b' cd' b_lt b_lt' ,
              rec' m b_lt' b cd = Some (a, b', cd')
              -> rec (build_aligned_ByteString b) b_lt cd = Some (a, build_aligned_ByteString (projT2 b'), cd'))
          -> (forall m cd b b_lt b_lt' ,
                 rec' m b_lt' b cd = None
                 -> rec (build_aligned_ByteString b) b_lt cd = None)
          -> body (build_aligned_ByteString b) rec cd
             = match (body' n rec' b cd) with
               | Some (a, b', cd') => Some (a, build_aligned_ByteString (projT2 b'), cd')
               | None => None
               end)
      -> Fix well_founded_lt_b (fun _ : ByteString => CacheDecode -> option (A * ByteString * CacheDecode)) body (build_aligned_ByteString b) cd =
         match Fix Wf_nat.lt_wf (fun m : nat => Vector.t (word 8) m -> CacheDecode -> option (A * { n : _ & Vector.t _ n} * CacheDecode)) body' n b cd with
         | Some (a, b', cd') => Some (a, build_aligned_ByteString (projT2 b'), cd')
         | None => None
         end.
  Proof.
    intros.
    revert cd b; pattern n.
    eapply (well_founded_ind Wf_nat.lt_wf); intros.
    rewrite Init.Wf.Fix_eq, Init.Wf.Fix_eq.
    apply H; intros.
    erewrite H0, H1; eauto.
    rewrite H0, H1; eauto.
    eauto.
    eauto.
  Qed.

  Lemma lift_match_if_ByteAlign
        {T1}
        {T2 T3 T4 A : T1 -> Type}
        {B B' C}
    : forall (b : bool)
             (t1 : T1)
             (t e : option (A t1 * B * C))
             (b' : forall t1, T2 t1 -> T3 t1 -> T4 t1 -> bool)
             (t' e' : forall t1, T2 t1 -> T3 t1 -> T4 t1 -> option (A t1 * B' * C))
             (f : B' -> B)
             (t2 : T2 t1)
             (t3 : T3 t1)
             (t4 : T4 t1),
      (b = b' t1 t2 t3 t4)
      -> (t = match t' t1 t2 t3 t4 with
              | Some (a, b', c) => Some (a, f b', c)
              | None => None
              end)
      -> (e = match e' t1 t2 t3 t4 with
              | Some (a, b', c) => Some (a, f b', c)
              | None => None
              end)
      -> (if b then t else e) =
         match (fun t1 t2 t3 t4 => if b' t1 t2 t3 t4 then t' t1 t2 t3 t4 else e' t1 t2 t3 t4) t1 t2 t3 t4 with
         | Some (a, b', c) => Some (a, f b', c)
         | None => None
         end.
  Proof.
    intros; destruct b; eauto; rewrite <- H; simpl; eauto.
  Qed.

  Lemma lift_match_if_sumbool_ByteAlign
        {T1}
        {T3 : T1 -> Type}
        {P : forall t1 (t3 : T3 t1), Prop}
        {T2 T4 A : T1 -> Type}
        {B B' C}
    : forall (t1 : T1)
             (t3 : T3 t1)
             (b : forall t1 t3, {P t1 t3} + {~P t1 t3})
             (t : _ -> option (A t1 * B * C))
             (e : _ -> option (A t1 * B * C))
             (b' : forall t1 t3, T2 t1 -> T4 t1 -> {P t1 t3} + {~P t1 t3})
             (t' : forall t1 t3, T2 t1 -> T4 t1 -> _ -> option (A t1 * B' * C))
             (e' : forall t1 t3, T2 t1 -> T4 t1 -> _ -> option (A t1 * B' * C))
             (f : B' -> B)
             (t2 : T2 t1)
             (t4 : T4 t1),
      (b t1 t3 = b' t1 t3 t2 t4)
      -> (forall e'',
             t e'' = match t' t1 t3 t2 t4 e'' with
                     | Some (a, b', c) => Some (a, f b', c)
                     | None => None
                     end)
      -> (forall e'',
             e e'' = match e' t1 t3 t2 t4 e'' with
                     | Some (a, b', c) => Some (a, f b', c)
                     | None => None
                     end)
      -> (match b t1 t3 with
            left e'' => t e''
          | right e'' => e e''
          end) =
         match (fun t1 t2 t3 t4 =>
                  match b' t1 t3 t2 t4 with
                  | left e'' => t' t1 t3 t2 t4 e''
                  | right e'' => e' t1 t3 t2 t4 e''
                  end) t1 t2 t3 t4 with
         | Some (a, b', c) => Some (a, f b', c)
         | None => None
         end.
  Proof.
    intros; destruct b; eauto; rewrite <- H; simpl; eauto.
  Qed.

  Lemma decode_word_aligned_ByteString_overflow
        {sz}
    : forall {sz'}
             (b : t (word 8) sz')
             (cd : CacheDecode),
      lt sz' sz
      -> decode_word (sz := 8 * sz) (build_aligned_ByteString b) cd = None.
  Proof.
  Admitted.

  Lemma build_aligned_ByteString_eq_split'
    : forall n sz v,
      (n <= sz)%nat
      ->
      build_aligned_ByteString v
      = build_aligned_ByteString (Guarded_Vector_split n sz v).
  Proof.
    intros; eapply ByteString_f_equal; simpl.
    instantiate (1 := eq_refl _); reflexivity.
    instantiate (1 := (le_plus_minus_r _ _ H)).
    generalize (le_plus_minus_r n sz H); clear.
    revert sz v; induction n; simpl; intros.
    unfold Guarded_Vector_split.
    rewrite <- Equality.transport_pp.
    generalize (eq_trans (minus_n_O sz) e); clear;
      intro.
    apply Eqdep_dec.eq_rect_eq_dec; auto with arith.
    destruct v; simpl in *.
    omega.
    unfold Guarded_Vector_split; fold Guarded_Vector_split;
      simpl.
    erewrite eq_rect_Vector_cons; eauto.
    f_equal.
    apply IHn.
    Grab Existential Variables.
    omega.
  Qed.

  Lemma optimize_Guarded_Decode {sz} {C} n
    : forall (a_opt : ByteString -> option C)
             (a_opt' : ByteString -> option C) v,
      (~ (n <= sz)%nat
       -> a_opt (build_aligned_ByteString v) = None)
      -> (le n sz -> a_opt  (build_aligned_ByteString (Guarded_Vector_split n sz v))
                     = a_opt'
                         (build_aligned_ByteString (Guarded_Vector_split n sz v)))
      -> a_opt (build_aligned_ByteString v) =
         If NPeano.leb n sz Then
            a_opt' (build_aligned_ByteString (Guarded_Vector_split n sz v))
            Else None.
  Proof.
    intros; destruct (NPeano.leb n sz) eqn: ?.
    - apply NPeano.leb_le in Heqb.
      rewrite <- H0.
      simpl; rewrite <- build_aligned_ByteString_eq_split'; eauto.
      eauto.
    - rewrite H; simpl; eauto.
      intro.
      rewrite <- NPeano.leb_le in H1; congruence.
  Qed.

  Lemma AlignedDecode4Char {C}
        {numBytes}
    : forall (v : Vector.t (word 8) (S (S (S (S numBytes)))))
             (t : _ -> C)
             (e : C)
             cd,
      Ifopt (decode_word
        (transformerUnit := ByteString_QueueTransformerOpt) (sz := 32) (build_aligned_ByteString v) cd) as w
      Then t w Else e  =
      Let n := Core.append_word (Vector.nth v (Fin.FS (Fin.FS (Fin.FS Fin.F1))))
                                (Core.append_word (Vector.nth v (Fin.FS (Fin.FS Fin.F1)))
                                                  (Core.append_word (Vector.nth v (Fin.FS Fin.F1)) (Vector.nth v Fin.F1))) in
        t (n, build_aligned_ByteString (snd (Vector_split 4 _ v)), addD cd 32).
  Proof.
    unfold LetIn; intros.
    unfold decode_word, WordOpt.decode_word.
    match goal with
      |- context[Ifopt ?Z as _ Then _ Else _] => replace Z with
                                                 (let (v', v'') := Vector_split 4 numBytes v in Some (VectorByteToWord v', build_aligned_ByteString v'')) by (symmetry; apply (@aligned_decode_char_eq' _ 3 v))
    end.
    Local Transparent Vector_split.
    unfold Vector_split, If_Opt_Then_Else, If_Opt_Then_Else.
    f_equal.
    rewrite !Vector_nth_tl, !Vector_nth_hd.
    erewrite VectorByteToWord_cons.
    rewrite <- !Eqdep_dec.eq_rect_eq_dec; eauto using Peano_dec.eq_nat_dec.
    f_equal.
    erewrite VectorByteToWord_cons.
    rewrite <- !Eqdep_dec.eq_rect_eq_dec; eauto using Peano_dec.eq_nat_dec.
    erewrite VectorByteToWord_cons.
    rewrite <- !Eqdep_dec.eq_rect_eq_dec; eauto using Peano_dec.eq_nat_dec.
    erewrite VectorByteToWord_cons.
    rewrite <- !Eqdep_dec.eq_rect_eq_dec; eauto using Peano_dec.eq_nat_dec.
    Grab Existential Variables.
    omega.
    omega.
    omega.
    omega.
  Qed.

  Lemma split2_split2
    : forall n m o (w : word (n + (m + o))),
      split2' m o (split2' n (m + o) w) =
      split2' (n + m) o (eq_rect _ _ w _ (plus_assoc _ _ _)).
  Proof.
    induction n; simpl; intros.
    - rewrite <- Eqdep_dec.eq_rect_eq_dec; auto with arith.
    - rewrite IHn.
      f_equal.
      pose proof (shatter_word_S w); destruct_ex; subst.
      clear.
      rewrite <- WS_eq_rect_eq with (H := plus_assoc n m o).
      admit.
  Qed.

  Lemma AlignedEncode32Char {numBytes}
    : forall (w : word 32) ce ce' (c : _ -> Comp _) (v : Vector.t _ numBytes),
      refine (c (addE ce 32)) (ret (build_aligned_ByteString v, ce'))
      -> refine (((encode_word_Spec (transformerUnit := ByteString_QueueTransformerOpt) w)
                   ThenC c) ce)
                (ret (build_aligned_ByteString
                        (Vector.cons
                           _ (split1' 8 24 w) _
                           (Vector.cons
                              _
                              (split1' 8 16 (split2' 8 24 w)) _
                              (Vector.cons
                                 _
                                 (split1' 8 8 (split2' 16 16 w)) _
                                 (Vector.cons
                                    _
                                    (split2' 24 8 w) _ v)))), ce')).
  Proof.
    unfold compose, Bind2; intros.
    intros; setoid_rewrite (@encode_words 8 24 w).
    rewrite (@AlignedEncodeChar 3).
    simplify with monad laws.
    unfold snd.
    rewrite H.
    simplify with monad laws.
    unfold fst.
    simpl transform.
    rewrite <- build_aligned_ByteString_append.
    instantiate (1 := Vector.cons _ _ _ (Vector.cons _ _ _ (Vector.cons _ _ _ (Vector.nil _)))).
    unfold append.
    reflexivity.
    setoid_rewrite (@encode_words 8 16 _).
    rewrite (@AlignedEncodeChar 2).
    reflexivity.
    setoid_rewrite (@encode_words 8 8).
    rewrite (@AlignedEncodeChar 1) by apply aligned_encode_char_eq.
    rewrite !addE_addE_plus; simpl plus.
    rewrite !split2_split2.
    simpl plus.
    rewrite <- !Eqdep_dec.eq_rect_eq_dec; auto with arith.
    reflexivity.
  Qed.

  Fixpoint align_decode_list {A}
           (A_decode_align : forall n,
               Vector.t (word 8) n
               -> CacheDecode
               -> option (A * {n : _ & Vector.t _ n}
                          * CacheDecode))
           (n : nat)
           {sz}
           (v : Vector.t (word 8) sz)
           (cd : CacheDecode)
    : option (list A *  {n : _ & Vector.t _ n} * CacheDecode) :=
    match n with
    | 0 => Some (@nil _, existT _ _ v, cd)
    | S s' => `(x, b1, e1) <- A_decode_align sz v cd;
                `(xs, b2, e2) <- align_decode_list A_decode_align s' (projT2 b1) e1;
                Some ((x :: xs)%list, b2, e2)
    end.

  Lemma optimize_align_decode_list
        {A}
        (A_decode :
           ByteString
           -> CacheDecode
           -> option (A * ByteString * CacheDecode))
        (A_decode_align : forall n,
            Vector.t (word 8) n
            -> CacheDecode
            -> option (A * {n : _ & Vector.t _ n}
                       * CacheDecode))
        (A_decode_OK :
           forall n (v : Vector.t _ n) cd,
             A_decode (build_aligned_ByteString v) cd =
             Ifopt A_decode_align n v cd as a Then
                                              Some (fst (fst a), build_aligned_ByteString (projT2 (snd (fst a))), snd a)
                                              Else
                                              None)
    : forall (n : nat)
             {sz}
             (v : Vector.t (word 8) sz)
             (cd : CacheDecode),
      decode_list A_decode n (build_aligned_ByteString v) cd =
      Ifopt align_decode_list A_decode_align n v cd as a Then
                                                         Some (fst (fst a), build_aligned_ByteString (projT2 (snd (fst a))), snd a)
                                                         Else
                                                         None.
  Proof.
    induction n; simpl; intros; eauto.
    rewrite A_decode_OK.
    rewrite (If_Opt_Then_Else_DecodeBindOpt).
    destruct (A_decode_align sz v cd) as [ [ [? [? ?] ] ?]  | ]; simpl; eauto.
    rewrite IHn.
    rewrite (If_Opt_Then_Else_DecodeBindOpt).
    destruct (align_decode_list A_decode_align n t c)
      as [ [ [? [? ?] ] ?]  | ]; simpl; eauto.
  Qed.

    Fixpoint align_encode_list {A}
             (A_encode_align :
                A
                ->  CacheEncode
                -> {n : _ & Vector.t (word 8) n} * CacheEncode)
             (As : list A)
             (ce : CacheEncode)
      : {n : _ & Vector.t (word 8) n} * CacheEncode :=
      match As with
             | nil => (existT _ _ (Vector.nil _), ce)
             | a :: As' =>
               let (b, ce') := A_encode_align a ce in
               let (b', ce'') := align_encode_list A_encode_align As' ce' in
               (existT _ _ (append (projT2 b) (projT2 b')), ce'')
      end.

    Lemma optimize_align_encode_list
          {A}
          (A_encode_Spec : A -> CacheEncode -> Comp (ByteString * CacheEncode))
          (A_encode_align :
             A
             ->  CacheEncode
             -> {n : _ & Vector.t (word 8) n} * CacheEncode)
          (A_encode_OK :
             forall a ce,
               refine (A_encode_Spec a ce)
                      (ret (let (v', ce') := A_encode_align a ce in
                            (build_aligned_ByteString (projT2 v'), ce'))))
      : forall (As : list A)
               (ce : CacheEncode),
        refine (encode_list_Spec A_encode_Spec As ce)
               (let (v', ce') := (align_encode_list A_encode_align As ce) in
                ret (build_aligned_ByteString (projT2 v'), ce')).
  Proof.
    induction As; simpl; intros; simpl.
    - simpl.
      repeat f_equiv.
      eapply ByteString_f_equal.
      instantiate (1 := eq_refl _); reflexivity.
      instantiate (1 := eq_refl _); reflexivity.
    - unfold Bind2.
      rewrite A_encode_OK; simplify with monad laws.
      rewrite IHAs.
      destruct (A_encode_align a ce); simpl.
      destruct (align_encode_list A_encode_align As c);
        simplify with monad laws.
      simpl.
      rewrite <- build_aligned_ByteString_append.
      reflexivity.
  Qed.

  Lemma LetIn_If_Opt_Then_Else {A B C}
    : forall (a : A)
             (k : A -> option B)
             (t : B -> C)
             (e : C),
      (Ifopt LetIn a k as b Then t b Else e)
      = LetIn a (fun a => Ifopt k a as b Then t b Else e).
  Proof.
    reflexivity.
  Qed.


  Lemma decode_unused_word_aligned_ByteString_overflow
        {sz}
    : forall {sz'}
             (b : t (word 8) sz')
             (cd : CacheDecode),
      lt sz' sz
      -> decode_unused_word (8 * sz) (build_aligned_ByteString b) cd = None.
  Proof.
  Admitted.


  Lemma aligned_decode_unused_char_eq
        {numBytes}
    : forall (v : Vector.t (word 8) (S numBytes)),
      WordOpt.decode_unused_word' (transformerUnit := ByteString_QueueTransformerOpt) 8 (build_aligned_ByteString v)
      = Some ((), build_aligned_ByteString (Vector.tl v)).
  Proof.
  Admitted.

  Lemma AlignedDecodeUnusedChars {C}
        {numBytes numBytes'}
    : forall (v : Vector.t (word 8) (numBytes' + numBytes))
             (k : _ -> option C)
             cd,
      BindOpt (decode_unused_word
        (transformerUnit := ByteString_QueueTransformerOpt) (8 * numBytes') (build_aligned_ByteString v) cd) k =
      k ((), build_aligned_ByteString (snd (Vector_split numBytes' _ v)), addD cd (8 * numBytes')).
  Proof.
    induction numBytes'; simpl; intros.
    - Local Transparent Vector_split.
      unfold Vector_split; simpl.
      reflexivity.
    - unfold decode_unused_word.
      replace (S
                 (numBytes' +
                  S
                    (numBytes' +
                     S
                       (numBytes' +
                        S
                          (numBytes' +
                           S (numBytes' + S (numBytes' + S (numBytes' + S (numBytes' + 0))))))))) with (8 + 8 * numBytes') by omega.
  Admitted.

  Lemma AlignedEncodeUnusedChar {numBytes}
    : forall ce ce' (c : _ -> Comp _) (v : Vector.t _ numBytes),
      refine (c (addE ce 8)) (ret (build_aligned_ByteString v, ce'))
      -> refine (((encode_unused_word_Spec (transformerUnit := ByteString_QueueTransformerOpt) 8)
                   ThenC c) ce)
                (ret (build_aligned_ByteString (Vector.cons _ (wzero 8) _ v), ce')).
  Proof.
  Admitted.

  Lemma AlignedEncode2UnusedChar {numBytes}
    : forall ce ce' (c : _ -> Comp _) (v : Vector.t _ numBytes),
      refine (c (addE ce 16)) (ret (build_aligned_ByteString v, ce'))
      -> refine (((encode_unused_word_Spec (transformerUnit := ByteString_QueueTransformerOpt) 16)
                   ThenC c) ce)
                (ret (build_aligned_ByteString (Vector.cons _ (wzero 8) _ (Vector.cons _ (wzero 8) _ v)), ce')).
  Proof.
  Admitted.

  Definition align_decode_sumtype
             {m : nat}
             {types : t Type m}
             (decoders :
                ilist (B := fun T =>
                              forall n,
                                Vector.t (word 8) n
                                -> CacheDecode
                                -> option (T * {n : _ & Vector.t (word 8) n} * CacheDecode)) types)
             (idx : Fin.t m)
             {n : nat}
             (v : Vector.t (word 8) n)
             (cd : CacheDecode)
    := `(a, b', cd') <- ith (decoders) idx n v cd;
         Some (inj_SumType types idx a, b', cd').

  Lemma align_decode_sumtype_OK'
        {m : nat}
        {types : t Type m}
        (align_decoders :
           ilist (B := fun T =>
                         forall n,
                           Vector.t (word 8) n
                           -> CacheDecode
                           -> option (T * {n : _ & Vector.t (word 8) n} * CacheDecode)) types)

        (decoders : ilist (B := fun T => ByteString -> CacheDecode -> option (T * ByteString * CacheDecode)) types)
        (decoders_OK : forall n v cd idx',
            ith decoders idx' (build_aligned_ByteString v) cd
            = Ifopt ith align_decoders idx' n v cd as a Then
                                                        Some (fst (fst a), build_aligned_ByteString (projT2 (snd (fst a))), snd a)
                                                        Else
                                                        None)
    : forall
      (idx : Fin.t m)
      {n : nat}
      (v : Vector.t (word 8) n)
      (cd : CacheDecode),
      decode_SumType types decoders idx (build_aligned_ByteString v) cd
      =
      Ifopt align_decode_sumtype align_decoders idx
            v cd as a Then
                      Some (fst (fst a), build_aligned_ByteString (projT2 (snd (fst a))), snd a)
                      Else
                      None.
  Proof.
    intros.
    unfold decode_SumType, align_decode_sumtype.
    rewrite decoders_OK.
    destruct (ith align_decoders idx n v cd) as [ [ [? ?] ?] | ];
      reflexivity.
  Qed.

  Corollary align_decode_sumtype_OK
            {m : nat}
            {types : t Type m}
            (align_decoders :
               ilist (B := fun T =>
                             forall n,
                               Vector.t (word 8) n
                               -> CacheDecode
                               -> option (T * {n : _ & Vector.t (word 8) n} * CacheDecode)) types)

            (decoders : ilist (B := fun T => ByteString -> CacheDecode -> option (T * ByteString * CacheDecode)) types)
            (decoders_OK : forall n v cd,
                Iterate_Ensemble_BoundedIndex
                  (fun idx' => ith decoders idx' (build_aligned_ByteString v) cd
                               = Ifopt ith align_decoders idx' n v cd as a Then
                                                                           Some (fst (fst a), build_aligned_ByteString (projT2 (snd (fst a))), snd a)
                                                                           Else
                                                                           None))
    : forall
      (idx : Fin.t m)
      {n : nat}
      (v : Vector.t (word 8) n)
      (cd : CacheDecode),
      decode_SumType types decoders idx (build_aligned_ByteString v) cd
      =
      Ifopt align_decode_sumtype align_decoders idx
            v cd as a Then
                      Some (fst (fst a), build_aligned_ByteString (projT2 (snd (fst a))), snd a)
                      Else
                      None.
  Proof.
    intros; eapply align_decode_sumtype_OK'; intros.
    pose proof (decoders_OK n0 v0 cd0).
    eapply Iterate_Ensemble_BoundedIndex_equiv in H.
    apply H.
  Qed.

  Definition align_encode_sumtype
             {m : nat}
             {types : t Type m}
             (encoders :
                ilist (B := (fun T : Type => T -> @CacheEncode cache -> ({n : _ & Vector.t (word 8) n} * (CacheEncode)))) types)
             (st : SumType types)
             (ce : CacheEncode)
    := ith (encoders) (SumType_index types st) (SumType_proj types st) ce.

  Lemma align_encode_sumtype_OK'
        {m : nat}
        {types : t Type m}
        (align_encoders :
                ilist (B := (fun T : Type => T -> @CacheEncode cache -> ({n : _ & Vector.t (word 8) n} * (CacheEncode)))) types)
        (encoders :
           ilist (B := (fun T : Type => T -> @CacheEncode cache -> Comp (ByteString * (CacheEncode)))) types)
        (encoders_OK : forall idx t (ce : CacheEncode),
            refine (ith encoders idx t ce)
                   (ret (build_aligned_ByteString (projT2 (fst (ith align_encoders idx t ce))),
                         snd (ith align_encoders idx t ce))))
    : forall (st : SumType types)
             (ce : CacheEncode),
      refine (encode_SumType_Spec types encoders st ce)
             (ret (build_aligned_ByteString (projT2 (fst (align_encode_sumtype align_encoders st ce))),
                   (snd (align_encode_sumtype align_encoders st ce)))).
  Proof.
    intros; unfold encode_SumType_Spec, align_encode_sumtype.
    rewrite encoders_OK; reflexivity.
  Qed.

  Corollary align_encode_sumtype_OK
        {m : nat}
        {types : t Type m}
        (align_encoders :
                ilist (B := (fun T : Type => T -> @CacheEncode cache -> ({n : _ & Vector.t (word 8) n} * (CacheEncode)))) types)
        (encoders :
           ilist (B := (fun T : Type => T -> @CacheEncode cache -> Comp (ByteString * (CacheEncode)))) types)
        (encoders_OK : Iterate_Ensemble_BoundedIndex (fun idx => forall t (ce : CacheEncode),
            refine (ith encoders idx t ce)
                   (ret (build_aligned_ByteString (projT2 (fst (ith align_encoders idx t ce))),
                         snd (ith align_encoders idx t ce)))))
    : forall (st : SumType types)
             (ce : CacheEncode),
      refine (encode_SumType_Spec types encoders st ce)
             (ret (build_aligned_ByteString (projT2 (fst (align_encode_sumtype align_encoders st ce))),
                   (snd (align_encode_sumtype align_encoders st ce)))).
  Proof.
    intros; eapply align_encode_sumtype_OK'; intros.
    eapply Iterate_Ensemble_BoundedIndex_equiv in encoders_OK.
    apply encoders_OK.
  Qed.

  Lemma nth_Vector_split {A}
    : forall {sz} n v idx,
      Vector.nth (snd (Vector_split (A := A) n sz v)) idx
      = Vector.nth v (Fin.R n idx).
  Proof.
    induction n; simpl; intros; eauto.
    assert (forall A n b, exists a b', b = Vector.cons A a n b')
      by (clear; intros; pattern n, b; apply caseS; eauto).
    pose proof (H _ _ v); destruct_ex; subst.
    simpl.
    destruct (Vector_split n sz x0) as [? ?] eqn: ?.
    rewrite <- IHn.
    rewrite Heqp; reflexivity.
  Qed.

  Lemma Vector_split_merge {A}
    : forall sz m n (v : Vector.t A _),
      snd (Vector_split m _ (snd (Vector_split n (m + sz) v))) =
      snd (Vector_split (n + m) _ (eq_rect _ _ v _ (plus_assoc _ _ _))).
  Proof.
    induction m; intros; simpl.
    - induction n; simpl.
      + simpl in *.
        apply Eqdep_dec.eq_rect_eq_dec; auto with arith.
      + simpl in v.
        assert (forall A n b, exists a b', b = Vector.cons A a n b')
          by (clear; intros; pattern n, b; apply caseS; eauto).
        pose proof (H _ _ v); destruct_ex; subst.
        simpl.
        pose proof (IHn x0).
        destruct (Vector_split n sz x0) eqn: ?.
        simpl in *.
        rewrite H0.
        erewrite eq_rect_Vector_cons with (H' := (plus_assoc n 0 sz)); eauto; simpl.
        destruct (Vector_split (n + 0) sz (eq_rect (n + sz) (Vector.t A) x0 (n + 0 + sz) (plus_assoc n 0 sz))); reflexivity.
    -
  Admitted.

End AlignedDecoders.
