(* (c) Copyright 2006-2016 Microsoft Corporation and Inria.                  *)
(* Distributed under the terms of CeCILL-B.                                  *)
Require Import mathcomp.ssreflect.ssreflect.
From mathcomp
Require Import ssrfun ssrbool.

(******************************************************************************)
(* This file defines two "base" combinatorial interfaces:                     *)
(*    eqType == the structure for types with a decidable equality.            *)
(* subType P == the structure for types isomorphic to {x : T | P x} with      *)
(*              P : pred T for some type T.                                   *)
(* The following are used to construct eqType instances:                      *)
(*         EqType T m == the packed eqType class for type T and mixin m.      *)
(* --> As eqType is a root class, equality mixins and classes coincide.       *)
(*   Equality.axiom e <-> e : rel T is a valid comparison decision procedure  *)
(*                       for type T: reflect (x = y) (e x y) for all x y : T. *)
(*         EqMixin eP == the equality mixin for eP : Equality.axiom e.        *)
(* --> Such manifest equality mixins should be declared Canonical to allow    *)
(* for generic folding of equality predicates (see lemma eqE below).          *)
(*  [eqType of T for eT] == clone for T of eT, where eT is an eqType for a    *)
(*                      type convertible, but usually not identical, to T.    *)
(*      [eqType of T] == clone for T of the eqType inferred for T, possibly   *)
(*                       after unfolding some definitions.                    *)
(*     [eqMixin of T] == mixin of the eqType inferred for T.                  *)
(*       comparable T <-> equality on T is decidable.                         *)
(*                    := forall x y : T, decidable (x = y)                    *)
(*  comparableMixin compT == equality mixin for compT : comparable T.         *)
(*   InjEqMixin injf == an Equality mixin for T, using an f : T -> U  where   *)
(*                      U has an eqType structure and injf : injective f.     *)
(*    PcanEqMixin fK == an Equality mixin similarly derived from f and a left *)
(*                      inverse partial function g and fK : pcancel f g.      *)
(*     CanEqMixin fK == an Equality mixin similarly derived from f and a left *)
(*                      inverse function g and fK : cancel f g.               *)
(* --> Equality mixins derived by the above should never be made Canonical as *)
(* they provide only comparisons with a generic head constant.                *)
(*   The eqType interface supports the following operations:                  *)
(*              x == y <=> x compares equal to y (this is a boolean test).    *)
(*         x == y :> T <=> x == y at type T.                                  *)
(*              x != y <=> x and y compare unequal.                           *)
(*         x != y :> T <=> x and y compare unequal at type T.                 *)
(*             x =P y  :: a proof of reflect (x = y) (x == y); x =P y coerces *)
(*                     to x == y -> x = y.                                    *)
(*               eq_op == the boolean relation behing the == notation.        *)
(*             pred1 a == the singleton predicate [pred x | x == a].          *)
(* pred2, pred3, pred4 == pair, triple, quad predicates.                      *)
(*            predC1 a == [pred x | x != a].                                  *)
(*      [predU1 a & A] == [pred x | (x == a) || (x \in A)].                   *)
(*      [predD1 A & a] == [pred x | x != a & x \in A].                        *)
(*  predU1 a P, predD1 P a == applicative versions of the above.              *)
(*              frel f == the relation associated with f : T -> T.            *)
(*                     := [rel x y | f x == y].                               *)
(*       invariant k f == elements of T whose k-class is f-invariant.         *)
(*                     := [pred x | k (f x) == k x] with f : T -> T.          *)
(*  [fun x : T => e0 with a1 |-> e1, .., a_n |-> e_n]                         *)
(*  [eta f with a1 |-> e1, .., a_n |-> e_n] ==                                *)
(*    the auto-expanding function that maps x = a_i to e_i, and other values  *)
(*    of x to e0 (resp. f x). In the first form the `: T' is optional and x   *)
(*    can occur in a_i or e_i.                                                *)
(* Equality on an eqType is proof-irrelevant (lemma eq_irrelevance).          *)
(*   The eqType interface is implemented for most standard datatypes:         *)
(*  bool, unit, void, option, prod (denoted A * B), sum (denoted A + B),      *)
(*  sig (denoted {x | P}), sigT (denoted {i : I & T}). We also define         *)
(*   tagged_as u v == v cast as T_(tag u) if tag v == tag u, else u.          *)
(*  -> We have u == v <=> (tag u == tag v) && (tagged u == tagged_as u v).    *)
(* The subType interface supports the following operations:                   *)
(*      val == the generic injection from a subType S of T into T.            *)
(*             For example, if u : {x : T | P}, then val u : T.               *)
(*             val is injective because P is proof-irrelevant (P is in bool,  *)
(*             and the is_true coercion expands to P = true).                 *)
(*     valP == the generic proof of P (val u) for u : subType P.              *)
(* Sub x Px == the generic constructor for a subType P; Px is a proof of P x  *)
(*             and P should be inferred from the expected return type.        *)
(*  insub x == the generic partial projection of T into a subType S of T.     *)
(*             This returns an option S; if S : subType P then                *)
(*                insub x = Some u with val u = x if P x,                     *)
(*                          None if ~~ P x                                    *)
(*             The insubP lemma encapsulates this dichotomy.                  *)
(*             P should be infered from the expected return type.             *)
(*  innew x == total (non-option) variant of insub when P = predT.            *)
(* {? x | P} == option {x | P} (syntax for casting insub x).                  *)
(* insubd u0 x == the generic projection with default value u0.               *)
(*             := odflt u0 (insub x).                                         *)
(* insigd A0 x == special case of insubd for S == {x | x \in A}, where A0 is  *)
(*                a proof of x0 \in A.                                        *)
(* insub_eq x == transparent version of insub x that expands to Some/None     *)
(*               when P x can evaluate.                                       *)
(* The subType P interface is most often implemented using one of:            *)
(*   [subType for S_val]                                                      *)
(*     where S_val : S -> T is the first projection of a type S isomorphic to *)
(*     {x : T | P}.                                                           *)
(*   [newType for S_val]                                                      *)
(*     where S_val : S -> T is the projection of a type S isomorphic to       *)
(*     wrapped T; in this case P must be predT.                               *)
(*   [subType for S_val by Srect], [newType for S_val by Srect]               *)
(*     variants of the above where the eliminator is explicitly provided.     *)
(*     Here S no longer needs to be syntactically identical to {x | P x} or   *)
(*     wrapped T, but it must have a derived constructor S_Sub statisfying an *)
(*     eliminator Srect identical to the one the Coq Inductive command would  *)
(*     have generated, and S_val (S_Sub x Px) (resp. S_val (S_sub x) for the  *)
(*     newType form) must be convertible to x.                                *)
(*     variant of the above when S is a wrapper type for T (so P = predT).    *)
(*   [subType of S], [subType of S for S_val]                                 *)
(*     clones the canonical subType structure for S; if S_val is specified,   *)
(*     then it replaces the inferred projector.                               *)
(* Subtypes inherit the eqType structure of their base types; the generic     *)
(* structure should be explicitly instantiated using the                      *)
(*   [eqMixin of S by <:]                                                     *)
(* construct to declare the equality mixin; this pattern is repeated for all  *)
(* the combinatorial interfaces (Choice, Countable, Finite). As noted above,  *)
(* such mixins should not be made Canonical.                                  *)
(*   We add the following to the standard suffixes documented in ssrbool.v:   *)
(*  1, 2, 3, 4 -- explicit enumeration predicate for 1 (singleton), 2, 3, or  *)
(*                4 values.                                                   *)
(******************************************************************************)

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

(* FIXME *)
(* Enrico's hack for have and pose to trigger TC inference *)
Notation "!! x" := (ltac:(refine x)) (at level 200) : form_scope.

Module Equality.

Definition axiom T (e : rel T) := forall x y, reflect (x = y) (e x y).

Class class T := Class { op : rel T; opP : axiom op }.
Arguments op {T _} : simpl never.
Hint Mode class ! : typeclass_instances.

Definition sort T & class T := T.
Definition class_of T (cT: class T) := cT.
Arguments class_of _ [cT].

Module Exports.
Notation eqClass := class.
Notation EqClass := Class.

Notation "[ 'eqClass' 'of' T ]" := (class_of _ : eqClass T)
  (at level 0, format "[ 'eqClass'  'of'  T ]") : form_scope.
Notation eq_op := op.

End Exports.

End Equality.
Export Equality.Exports.

(* eqE is a generic lemma that can be used to fold back recursive comparisons *)
(* after using partial evaluation to simplify comparisons on concrete         *)
(* instances. The eqE lemma can be used e.g. like so: rewrite !eqE /= -!eqE.  *)
(* For instance, with the above rewrite, n.+1 == n.+1 gets simplified to      *)
(* n == n. For this to work, we need to declare equality _mixins_             *)
(* as canonical. Canonical declarations remove the need for specific          *)
(* inverses to eqE (like eqbE, eqnE, eqseqE, etc.) for new recursive          *)
(* comparisons, but can only be used for manifest mixing with a bespoke       *)
(* comparison function, and so is incompatible with PcanEqMixin and the like  *)
(* - this is why the tree_eqMixin for GenTree.tree in library choice is not   *)
(* declared Canonical.                                                        *)
Lemma eqE T `(eqClass T) x : eq_op x = Equality.op x.
Proof. by []. Qed.

Lemma eqP T (cT: eqClass T) : Equality.axiom (@eq_op T _).
Proof. exact: Equality.opP. Qed.
Arguments eqP {T cT x y}.

Delimit Scope eq_scope with EQ.
Open Scope eq_scope.

Notation "x == y" := (eq_op x y)
  (at level 70, no associativity) : bool_scope.
Notation "x == y :> T" := ((x : T) == (y : T))
  (at level 70, y at next level) : bool_scope.
Notation "x != y" := (~~ (x == y))
  (at level 70, no associativity) : bool_scope.
Notation "x != y :> T" := (~~ (x == y :> T))
  (at level 70, y at next level) : bool_scope.
Notation "x =P y" := (eqP : reflect (x = y) (x == y))
  (at level 70, no associativity) : eq_scope.
Notation "x =P y :> T" := (eqP : reflect (x = y :> T) (x == y :> T))
  (at level 70, y at next level, no associativity) : eq_scope.

Prenex Implicits eqP.

Lemma eq_refl T {cT: eqClass T} (x : T) : x == x. Proof. exact/eqP. Qed.
Notation eqxx := eq_refl.

Lemma eq_sym T {cT: eqClass T} (x y : T) : (x == y) = (y == x).
Proof. exact/eqP/eqP. Qed.

Hint Resolve eq_refl eq_sym : core.

Section Contrapositives.

Context T1 {cT1: eqClass T1} T2 {cT2: eqClass T2}.
Implicit Types (A : pred T1) (b : bool) (x : T1) (z : T2).

Lemma contraTeq b x y : (x != y -> ~~ b) -> b -> x = y.
Proof. by move=> imp hyp; apply/eqP; apply: contraTT hyp. Qed.

Lemma contraNeq b x y : (x != y -> b) -> ~~ b -> x = y.
Proof. by move=> imp hyp; apply/eqP; apply: contraNT hyp. Qed.

Lemma contraFeq b x y : (x != y -> b) -> b = false -> x = y.
Proof. by move=> imp /negbT; apply: contraNeq. Qed.

Lemma contraTneq b x y : (x = y -> ~~ b) -> b -> x != y.
Proof. by move=> imp; apply: contraTN => /eqP. Qed.

Lemma contraNneq b x y : (x = y -> b) -> ~~ b -> x != y.
Proof. by move=> imp; apply: contraNN => /eqP. Qed.

Lemma contraFneq b x y : (x = y -> b) -> b = false -> x != y.
Proof. by move=> imp /negbT; apply: contraNneq. Qed.

Lemma contra_eqN b x y : (b -> x != y) -> x = y -> ~~ b.
Proof. by move=> imp /eqP; apply: contraL. Qed.

Lemma contra_eqF b x y : (b -> x != y) -> x = y -> b = false.
Proof. by move=> imp /eqP; apply: contraTF. Qed.

Lemma contra_eqT b x y : (~~ b -> x != y) -> x = y -> b.
Proof. by move=> imp /eqP; apply: contraLR. Qed.

Lemma contra_eq z1 z2 x1 x2 : (x1 != x2 -> z1 != z2) -> z1 = z2 -> x1 = x2.
Proof. by move=> imp /eqP; apply: contraTeq. Qed.

Lemma contra_neq z1 z2 x1 x2 : (x1 = x2 -> z1 = z2) -> z1 != z2 -> x1 != x2.
Proof. by move=> imp; apply: contraNneq => /imp->. Qed.

Lemma memPn A x : reflect {in A, forall y, y != x} (x \notin A).
Proof.
apply: (iffP idP) => [notDx y | notDx]; first by apply: contraTneq => ->.
exact: contraL (notDx x) _.
Qed.

Lemma memPnC A x : reflect {in A, forall y, x != y} (x \notin A).
Proof. by apply: (iffP (memPn A x)) => A'x y /A'x; rewrite eq_sym. Qed.

Lemma ifN_eq R x y vT vF : x != y -> (if x == y then vT else vF) = vF :> R.
Proof. exact: ifN. Qed.

Lemma ifN_eqC R x y vT vF : x != y -> (if y == x then vT else vF) = vF :> R.
Proof. by rewrite eq_sym; apply: ifN. Qed.

End Contrapositives.

Arguments memPn {T1 cT1 A x}.
Arguments memPnC {T1 cT1 A x}.

Theorem eq_irrelevance T (cT: eqClass T) x y : forall e1 e2 : x = y :> T, e1 = e2.
Proof.
pose proj z e := !! if x =P z is ReflectT e0 then e0 else e.
suff: injective (proj y) by rewrite /proj => injp e e'; apply: injp; case: eqP.
pose join (e : x = _) := etrans (esym e).
apply: can_inj (join x y (proj x (erefl x))) _.
by case: y /; case: _ / (proj x _).
Qed.

Corollary eq_axiomK T {cT: eqClass T} (x : T) : all_equal_to (erefl x).
Proof. by move=> eq_x_x; apply: eq_irrelevance. Qed.

Lemma unit_eqP : Equality.axiom (fun _ _ : unit => true).
Proof. by do 2!case; left. Qed.

Instance unit_eqClass : eqClass unit := EqClass unit_eqP.

(* Comparison for booleans. *)

(* This is extensionally equal, but not convertible to Bool.eqb. *)
Definition eqb b := addb (~~ b).

Lemma eqbP : Equality.axiom eqb.
Proof. by do 2!case; constructor. Qed.

Instance bool_eqClass : eqClass bool := EqClass eqbP.

Lemma eqbE : eqb = eq_op. Proof. by []. Qed.

Lemma bool_irrelevance (b : bool) (p1 p2 : b) : p1 = p2.
Proof. exact: eq_irrelevance. Qed.

Lemma negb_add b1 b2 : ~~ (b1 (+) b2) = (b1 == b2).
Proof. by rewrite -addNb. Qed.

Lemma negb_eqb b1 b2 : (b1 != b2) = b1 (+) b2.
Proof. by rewrite -addNb negbK. Qed.

Lemma eqb_id b : (b == true) = b.
Proof. by case: b. Qed.

Lemma eqbF_neg b : (b == false) = ~~ b.
Proof. by case: b. Qed.

Lemma eqb_negLR b1 b2 : (~~ b1 == b2) = (b1 == ~~ b2).
Proof. by case: b1; case: b2. Qed.

(* Equality-based predicates.       *)

Notation xpred1 := (fun a1 x => x == a1).
Notation xpred2 := (fun a1 a2 x => (x == a1) || (x == a2)).
Notation xpred3 := (fun a1 a2 a3 x => [|| x == a1, x == a2 | x == a3]).
Notation xpred4 :=
  (fun a1 a2 a3 a4 x => [|| x == a1, x == a2, x == a3 | x == a4]).
Notation xpredU1 := (fun a1 (p : pred _) x => (x == a1) || p x).
Notation xpredC1 := (fun a1 x => x != a1).
Notation xpredD1 := (fun (p : pred _) a1 x => (x != a1) && p x).

Section EqPred.

Context T {cT: eqClass T}.

Definition pred1 (a1 : T) := SimplPred (xpred1 a1).
Definition pred2 (a1 a2 : T) := SimplPred (xpred2 a1 a2).
Definition pred3 (a1 a2 a3 : T) := SimplPred (xpred3 a1 a2 a3).
Definition pred4 (a1 a2 a3 a4 : T) := SimplPred (xpred4 a1 a2 a3 a4).
Definition predU1 (a1 : T) p := SimplPred (xpredU1 a1 p).
Definition predC1 (a1 : T) := SimplPred (xpredC1 a1).
Definition predD1 p (a1 : T) := SimplPred (xpredD1 p a1).

Lemma pred1E : pred1 =2 eq_op. Proof. by move=> x y; apply: eq_sym. Qed.

Context T2 (cT2: eqClass T2) (x y : T) (z u : T2) (b : bool).

Lemma predU1P : reflect (x = y \/ b) ((x == y) || b).
Proof. by apply: (iffP orP); do [case=> [/eqP|]; [left | right]]. Qed.

Lemma pred2P : reflect (x = y \/ z = u) ((x == y) || (z == u)).
Proof. by apply: (iffP orP); do [case=> /eqP; [left | right]]. Qed.

Lemma predD1P : reflect (x <> y /\ b) ((x != y) && b).
Proof. by apply: (iffP andP)=> [] [] // /eqP. Qed.

Lemma predU1l : x = y -> (x == y) || b.
Proof. by move->; rewrite eqxx. Qed.

Lemma predU1r : b -> (x == y) || b.
Proof. by move->; rewrite orbT. Qed.

Lemma eqVneq : {x = y} + {x != y}.
Proof. by case: eqP; [left | right]. Qed.

End EqPred.

Arguments predU1P {T cT x y b}.
Arguments pred2P {T cT T2 cT2 x y z u}.
Arguments predD1P {T cT x y b}.
Prenex Implicits pred1 pred2 pred3 pred4 predU1 predC1 predD1 predU1P.

Notation "[ 'predU1' x & A ]" := (predU1 x [mem A])
  (at level 0, format "[ 'predU1'  x  &  A ]") : fun_scope.
Notation "[ 'predD1' A & x ]" := (predD1 [mem A] x)
  (at level 0, format "[ 'predD1'  A  &  x ]") : fun_scope.

(* Lemmas for reflected equality and functions.   *)

Section EqFun.

Section Exo.

Context aT {caT: eqClass aT} rT {crT: eqClass rT} (D : pred aT) (f : aT -> rT) (g : rT -> aT).

Lemma inj_eq : injective f -> forall x y, (f x == f y) = (x == y).
Proof. by move=> inj_f x y; apply/eqP/eqP=> [|-> //]; apply: inj_f. Qed.

Lemma can_eq : cancel f g -> forall x y, (f x == f y) = (x == y).
Proof. by move/can_inj; apply: inj_eq. Qed.

Lemma bij_eq : bijective f -> forall x y, (f x == f y) = (x == y).
Proof. by move/bij_inj; apply: inj_eq. Qed.

Lemma can2_eq : cancel f g -> cancel g f -> forall x y, (f x == y) = (x == g y).
Proof. by move=> fK gK x y; rewrite -{1}[y]gK; apply: can_eq. Qed.

Lemma inj_in_eq :
  {in D &, injective f} -> {in D &, forall x y, (f x == f y) = (x == y)}.
Proof. by move=> inj_f x y Dx Dy; apply/eqP/eqP=> [|-> //]; apply: inj_f. Qed.

Lemma can_in_eq :
  {in D, cancel f g} -> {in D &, forall x y, (f x == f y) = (x == y)}.
Proof. by move/can_in_inj; apply: inj_in_eq. Qed.

End Exo.

Section Endo.

Context T {cT: eqClass T}.

Definition frel f := [rel x y : T | f x == y].

Lemma inv_eq f : involutive f -> forall x y : T, (f x == y) = (x == f y).
Proof. by move=> fK; apply: can2_eq. Qed.

Lemma eq_frel f f' : f =1 f' -> frel f =2 frel f'.
Proof. by move=> eq_f x y; rewrite /= eq_f. Qed.

End Endo.

Variable aT : Type.

(* The invariant of an function f wrt a projection k is the pred of points *)
(* that have the same projection as their image.                           *)

Definition invariant rT {crT: eqClass rT} f (k : aT -> rT) :=
  [pred x | k (f x) == k x].
Arguments invariant [rT crT].

Context rT1 (crT1: eqClass rT1) rT2 (crT2: eqClass rT2) (f : aT -> aT) (h : rT1 -> rT2) (k : aT -> rT1).

Lemma invariant_comp : subpred (invariant f k) (invariant f (h \o k)).
Proof. by move=> x eq_kfx; rewrite /= (eqP eq_kfx). Qed.

Lemma invariant_inj : injective h -> invariant f (h \o k) =1 invariant f k.
Proof. by move=> inj_h x; apply: (inj_eq inj_h). Qed.

End EqFun.

Prenex Implicits frel.

(* The coercion to rel must be explicit for derived Notations to unparse. *)
Notation coerced_frel f := (rel_of_simpl_rel (frel f)) (only parsing).

Section FunWith.

Context aT {caT : eqClass aT} (rT : Type).

Variant fun_delta : Type := FunDelta of aT & rT.

Definition fwith x y (f : aT -> rT) := [fun z => if z == x then y else f z].

Definition app_fdelta df f z :=
  let: FunDelta x y := df in if z == x then y else f z.

End FunWith.

Prenex Implicits fwith.

Notation "x |-> y" := (FunDelta x y)
  (at level 190, no associativity,
   format "'[hv' x '/ '  |->  y ']'") : fun_delta_scope.

Delimit Scope fun_delta_scope with FUN_DELTA.
Arguments app_fdelta {aT caT rT%type} df%FUN_DELTA f z.

Notation "[ 'fun' z : T => F 'with' d1 , .. , dn ]" :=
  (SimplFunDelta (fun z : T =>
     app_fdelta d1%FUN_DELTA .. (app_fdelta dn%FUN_DELTA  (fun _ => F)) ..))
  (at level 0, z ident, only parsing) : fun_scope.

Notation "[ 'fun' z => F 'with' d1 , .. , dn ]" :=
  (SimplFunDelta (fun z =>
     app_fdelta d1%FUN_DELTA .. (app_fdelta dn%FUN_DELTA (fun _ => F)) ..))
  (at level 0, z ident, format
   "'[hv' [ '[' 'fun'  z  => '/ '  F ']' '/'  'with'  '[' d1 , '/'  .. , '/'  dn ']' ] ']'"
   ) : fun_scope.

Notation "[ 'eta' f 'with' d1 , .. , dn ]" :=
  (SimplFunDelta (fun _ =>
     app_fdelta d1%FUN_DELTA .. (app_fdelta dn%FUN_DELTA f) ..))
  (at level 0, format
  "'[hv' [ '[' 'eta' '/ '  f ']' '/'  'with'  '[' d1 , '/'  .. , '/'  dn ']' ] ']'"
  ) : fun_scope.

(* Various EqType constructions.                                         *)

Section ComparableType.

Variable T : Type.

Definition comparable := forall x y : T, decidable (x = y).

Hypothesis compare_T : comparable.

Definition compareb x y : bool := compare_T x y.

Lemma compareP : Equality.axiom compareb.
Proof. by move=> x y; apply: sumboolP. Qed.

Definition comparableClass := EqClass compareP.

End ComparableType.

Definition eq_comparable T (cT: eqClass T) : comparable T :=
  fun x y => decP (x =P y).

Section SubType.

Variables (T : Type) (P : pred T).

Structure subType : Type := SubType {
  sub_sort :> Type;
  val : sub_sort -> T;
  Sub : forall x, P x -> sub_sort;
  _ : forall K (_ : forall x Px, K (@Sub x Px)) u, K u;
  _ : forall x Px, val (@Sub x Px) = x
}.

(* Generic proof that the second property holds by conversion.                *)
(* The vrefl_rect alias is used to flag generic proofs of the first property. *)
Lemma vrefl : forall x, P x -> x = x. Proof. by []. Qed.
Definition vrefl_rect := vrefl.

Definition clone_subType U v :=
  fun sT & sub_sort sT -> U =>
  fun c Urec cK (sT' := @SubType U v c Urec cK) & phant_id sT' sT => sT'.

Section Theory.

Variable sT : subType.

Local Notation val := (@val sT).
Local Notation Sub x Px := (@Sub sT x Px).

Variant Sub_spec : sT -> Type := SubSpec x Px : Sub_spec (Sub x Px).

Lemma SubP u : Sub_spec u.
Proof. by case: sT Sub_spec SubSpec u => /= U _ mkU rec _. Qed.

Lemma SubK x Px : val (Sub x Px) = x. Proof. by case: sT. Qed.

Definition insub x := if idP is ReflectT Px then Some (Sub x Px) else None.

Definition insubd u0 x := odflt u0 (insub x).

Variant insub_spec x : option sT -> Type :=
  | InsubSome u of P x & val u = x : insub_spec x (Some u)
  | InsubNone   of ~~ P x          : insub_spec x None.

Lemma insubP x : insub_spec x (insub x).
Proof.
by rewrite /insub; case: {-}_ / idP; [left; rewrite ?SubK | right; apply/negP].
Qed.

Lemma insubT x Px : insub x = Some (Sub x Px).
Proof.
do [case: insubP => [/SubP[y Py] _ <- | /negP// ]; rewrite SubK]  in Px *.
by rewrite (bool_irrelevance Px Py).
Qed.

Lemma insubF x : P x = false -> insub x = None.
Proof. by move/idP; case: insubP. Qed.

Lemma insubN x : ~~ P x -> insub x = None.
Proof. by move/negPf/insubF. Qed.

Lemma isSome_insub : ([eta insub] : pred T) =1 P.
Proof. by apply: fsym => x; case: insubP => // /negPf. Qed.

Lemma insubK : ocancel insub val.
Proof. by move=> x; case: insubP. Qed.

Lemma valP u : P (val u).
Proof. by case/SubP: u => x Px; rewrite SubK. Qed.

Lemma valK : pcancel val insub.
Proof. by case/SubP=> x Px; rewrite SubK; apply: insubT. Qed.

Lemma val_inj : injective val.
Proof. exact: pcan_inj valK. Qed.

Lemma valKd u0 : cancel val (insubd u0).
Proof. by move=> u; rewrite /insubd valK. Qed.

Lemma val_insubd u0 x : val (insubd u0 x) = if P x then x else val u0.
Proof. by rewrite /insubd; case: insubP => [u -> | /negPf->]. Qed.

Lemma insubdK u0 : {in P, cancel (insubd u0) val}.
Proof. by move=> x Px; rewrite /= val_insubd [P x]Px. Qed.

Let insub_eq_aux x isPx : P x = isPx -> option sT :=
  if isPx as b return _ = b -> _ then fun Px => Some (Sub x Px) else fun=> None.
Definition insub_eq x := insub_eq_aux (erefl (P x)).

Lemma insub_eqE : insub_eq =1 insub.
Proof.
rewrite /insub_eq => x; set b := P x; rewrite [in LHS]/b in (Db := erefl b) *.
by case: b in Db *; [rewrite insubT | rewrite insubF].
Qed.

End Theory.

End SubType.

Arguments SubType {T P} sub_sort val Sub rec SubK.
Arguments val {T P sT} u : rename.
Arguments Sub {T P sT} x Px : rename.
Arguments vrefl {T P} x Px.
Arguments vrefl_rect {T P} x Px.
Arguments clone_subType [T P] U v [sT] _ [c Urec cK].
Arguments insub {T P sT} x.
Arguments insubd {T P sT} u0 x.
Arguments insubT [T] P [sT x].
Arguments val_inj {T P sT} [u1 u2] eq_u12 : rename.
Arguments valK {T P sT} u : rename.
Arguments valKd {T P sT} u0 u : rename.
Arguments insubK {T P} sT x.
Arguments insubdK {T P sT} u0 [x] Px.

Local Notation inlined_sub_rect :=
  (fun K K_S u => let (x, Px) as u return K u := u in K_S x Px).

Local Notation inlined_new_rect :=
  (fun K K_S u => let (x) as u return K u := u in K_S x).

Notation "[ 'subType' 'for' v ]" := (SubType _ v _ inlined_sub_rect vrefl_rect)
 (at level 0, only parsing) : form_scope.

Notation "[ 'sub' 'Type' 'for' v ]" := (SubType _ v _ _ vrefl_rect)
 (at level 0, format "[ 'sub' 'Type'  'for'  v ]") : form_scope.

Notation "[ 'subType' 'for' v 'by' rec ]" := (SubType _ v _ rec vrefl)
 (at level 0, format "[ 'subType'  'for'  v  'by'  rec ]") : form_scope.

Notation "[ 'subType' 'of' U 'for' v ]" := (clone_subType U v id idfun)
 (at level 0, format "[ 'subType'  'of'  U  'for'  v ]") : form_scope.

Notation "[ 'subType' 'of' U ]" := (clone_subType U _ id id)
 (at level 0, format "[ 'subType'  'of'  U ]") : form_scope.

Definition NewType T U v c Urec :=
  let Urec' P IH := Urec P (fun x : T => IH x isT : P _) in
  SubType U v (fun x _ => c x) Urec'.
Arguments NewType [T U].

Notation "[ 'newType' 'for' v ]" := (NewType v _ inlined_new_rect vrefl_rect)
 (at level 0, only parsing) : form_scope.

Notation "[ 'new' 'Type' 'for' v ]" := (NewType v _ _ vrefl_rect)
 (at level 0, format "[ 'new' 'Type'  'for'  v ]") : form_scope.

Notation "[ 'newType' 'for' v 'by' rec ]" := (NewType v _ rec vrefl)
 (at level 0, format "[ 'newType'  'for'  v  'by'  rec ]") : form_scope.

Definition innew T nT x := @Sub T predT nT x (erefl true).
Arguments innew {T nT}.

Lemma innew_val T nT : cancel val (@innew T nT).
Proof. by move=> u; apply: val_inj; apply: SubK. Qed.

(* Prenex Implicits and renaming. *)
Notation sval := (@proj1_sig _ _).
Notation "@ 'sval'" := (@proj1_sig) (at level 10, format "@ 'sval'").

Section SigProj.

Variables (T : Type) (P Q : T -> Prop).

Lemma svalP : forall u : sig P, P (sval u). Proof. by case. Qed.

Definition s2val (u : sig2 P Q) := let: exist2 x _ _ := u in x.

Lemma s2valP u : P (s2val u). Proof. by case: u. Qed.

Lemma s2valP' u : Q (s2val u). Proof. by case: u. Qed.

End SigProj.

Prenex Implicits svalP s2val s2valP s2valP'.

Canonical sig_subType T (P : pred T) : subType [eta P] :=
  Eval hnf in [subType for @sval T [eta [eta P]]].

(* Shorthand for sigma types over collective predicates. *)
Notation "{ x 'in' A }" := {x | x \in A}
  (at level 0, x at level 99, format  "{ x  'in'  A }") : type_scope.
Notation "{ x 'in' A | P }" := {x | (x \in A) && P}
  (at level 0, x at level 99, format  "{ x  'in'  A  |  P }") : type_scope.

(* Shorthand for the return type of insub. *)
Notation "{ ? x : T | P }" := (option {x : T | is_true P})
  (at level 0, x at level 99, only parsing) : type_scope.
Notation "{ ? x | P }" := {? x : _ | P}
  (at level 0, x at level 99, format  "{ ?  x  |  P }") : type_scope.
Notation "{ ? x 'in' A }" := {? x | x \in A}
  (at level 0, x at level 99, format  "{ ?  x  'in'  A }") : type_scope.
Notation "{ ? x 'in' A | P }" := {? x | (x \in A) && P}
  (at level 0, x at level 99, format  "{ ?  x  'in'  A  |  P }") : type_scope.

(* A variant of injection with default that infers a collective predicate *)
(* from the membership proof for the default value.                       *)
Definition insigd T (A : mem_pred T) x (Ax : in_mem x A) :=
  insubd (exist [eta A] x Ax).

(* There should be a rel definition for the subType equality op, but this *)
(* seems to cause the simpl tactic to diverge on expressions involving == *)
(* on 4+ nested subTypes in a "strict" position (e.g., after ~~).         *)
(* Definition feq f := [rel x y | f x == f y].                            *)

Section TransferEqType.

Context (T : Type) eT {ceT: eqClass eT} (f : T -> eT).

Lemma inj_eqAxiom : injective f -> Equality.axiom (fun x y => f x == f y).
Proof. by move=> f_inj x y; apply: (iffP eqP) => [|-> //]; apply: f_inj. Qed.

Definition InjEqClass f_inj := EqClass (inj_eqAxiom f_inj).

Definition PcanEqClass g (fK : pcancel f g) := InjEqClass (pcan_inj fK).

Definition CanEqClass g (fK : cancel f g) := InjEqClass (can_inj fK).

End TransferEqType.

Section SubEqType.

Context T {cT: eqClass T} (P : pred T) (sT : subType P).

Local Notation ev_ax := (fun T v => @Equality.axiom T (fun x y => v x == v y)).
Lemma val_eqP : ev_ax sT val. Proof. exact: inj_eqAxiom val_inj. Qed.

Global Instance sub_eqClass : eqClass sT := EqClass val_eqP.

Lemma val_eqE (u v : sT) : (val u == val v) = (u == v).
Proof. by []. Qed.

End SubEqType.

Arguments val_eqP {T cT P sT x y}.

(* Arguments SubEqClass [T cT P] sT. *)

Notation "[ 'eqClass' 'of' T 'by' <: ]" := (sub_eqClass _ : eqClass T)
  (at level 0, format "[ 'eqClass'  'of'  T  'by'  <: ]") : form_scope.

Section SigEqType.

Context T (cT: eqClass T) (P : pred T).

Global Instance sig_eqClass : eqClass { x | P x } := [eqClass of { x | P x } by <:].

End SigEqType.

Section ProdEqType.

Context T1 (cT1: eqClass T1) T2 (cT2: eqClass T2).

Definition pair_eq : rel (T1 * T2) := fun u v => (u.1 == v.1) && (u.2 == v.2).

Lemma pair_eqP : Equality.axiom pair_eq.
Proof.
move=> [x1 x2] [y1 y2] /=; apply: (iffP andP) => [[]|[<- <-]] //=.
by do 2!move/eqP->.
Qed.

Global Instance prod_eqClass : eqClass (T1 * T2) := EqClass pair_eqP.

Lemma pair_eqE : pair_eq = eq_op :> rel _. Proof. by []. Qed.

Lemma xpair_eqE (x1 y1 : T1) (x2 y2 : T2) :
  ((x1, x2) == (y1, y2)) = ((x1 == y1) && (x2 == y2)).
Proof. by []. Qed.

Lemma pair_eq1 (u v : T1 * T2) : u == v -> u.1 == v.1.
Proof. by case/andP. Qed.

Lemma pair_eq2 (u v : T1 * T2) : u == v -> u.2 == v.2.
Proof. by case/andP. Qed.

End ProdEqType.

Arguments pair_eq {T1 cT1 T2 cT2} u v /.
Arguments pair_eqP {T1 cT1 T2 cT2}.

Definition predX T1 T2 (p1 : pred T1) (p2 : pred T2) :=
  [pred z | p1 z.1 & p2 z.2].

Notation "[ 'predX' A1 & A2 ]" := (predX [mem A1] [mem A2])
  (at level 0, format "[ 'predX'  A1  &  A2 ]") : fun_scope.

Section OptionEqType.

Context T (cT: eqClass T).

Definition opt_eq (u v : option T) : bool :=
  oapp (fun x => oapp (eq_op x) false v) (~~ v) u.

Lemma opt_eqP : Equality.axiom opt_eq.
Proof.
case=> [x|] [y|] /=; by [constructor | apply: (iffP eqP) => [|[]] ->].
Qed.

Global Instance option_eqClass : eqClass (option T) := EqClass opt_eqP.

End OptionEqType.

Arguments opt_eq {T cT} !u !v.

Section TaggedAs.

Context I {cI: eqClass I} (T_ : I -> Type).
Implicit Types u v : {i : I & T_ i}.

Definition tagged_as u v :=
  if tag u =P tag v is ReflectT eq_uv then
    eq_rect_r T_ (tagged v) eq_uv
  else tagged u.

Lemma tagged_asE u x : tagged_as u (Tagged T_ x) = x.
Proof.
by rewrite /tagged_as /=; case: eqP => // eq_uu; rewrite [eq_uu]eq_axiomK.
Qed.

End TaggedAs.

Section TagEqType.

Context I {cI: eqClass I} (T_ : I -> Type).
Context {eqClassT_ : forall (i : I), eqClass (T_ i)}.
Implicit Types u v : {i : I & T_ i}.

Definition tag_eq u v := (tag u == tag v) && (tagged u == tagged_as u v).

Lemma tag_eqP : Equality.axiom tag_eq.
Proof.
rewrite /tag_eq => [] [i x] [j] /=.
case: (@eqP I) => [<-|Hij] y; last by right; case.
by apply: (iffP eqP) => [->|<-]; rewrite tagged_asE.
Qed.

Global Instance tag_eqClass : eqClass { i: I & T_ i} := EqClass tag_eqP.

Lemma tag_eqE : tag_eq = eq_op. Proof. by []. Qed.

Lemma eq_tag u v : u == v -> tag u = tag v.
Proof. by move/eqP->. Qed.

Lemma eq_Tagged u x : (u == Tagged _ x) = (tagged u == x).
Proof. by rewrite -tag_eqE /tag_eq eqxx tagged_asE. Qed.

End TagEqType.

Arguments tag_eq {I cI T_ eqClassT_} !u !v.
Arguments tag_eqP {I cI T_ eqClassT_ x y}.

Section SumEqType.

Context T1 (cT1: eqClass T1) T2 (cT2: eqClass T2).
Implicit Types u v : T1 + T2.

Definition sum_eq u v :=
  match u, v with
  | inl x, inl y | inr x, inr y => x == y
  | _, _ => false
  end.

Lemma sum_eqP : Equality.axiom sum_eq.
Proof. case=> x [] y /=; by [right | apply: (iffP eqP) => [->|[->]]]. Qed.

Global Instance sum_eqClass : eqClass (T1 + T2) := EqClass sum_eqP.

Lemma sum_eqE : sum_eq = eq_op. Proof. by []. Qed.

End SumEqType.

Arguments sum_eq {T1 cT1 T2 cT2} !u !v.
Arguments sum_eqP {T1 cT1 T2 cT2 x y}.
