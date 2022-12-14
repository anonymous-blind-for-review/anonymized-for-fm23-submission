{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2020, 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

open import LibraBFT.Base.Types
open import LibraBFT.ImplShared.Base.Types
open import Util.Lemmas
open import Util.Prelude

open import LibraBFT.Abstract.Types.EpochConfig UID NodeId
open        WithAbsVote

module LibraBFT.Concrete.Obligations.PreferredRound
  (π : EpochConfig)
  (π₯ : VoteEvidence π)
  where
 open import LibraBFT.Abstract.Abstract UID _βUID_ NodeId π π₯
 open import LibraBFT.Concrete.Intermediate               π π₯

 record VotesForBlock (v : Vote) : Set where
    constructor mkVE
    field
      veBlock   : Block
      veId      : vBlockUID v β‘ bId    veBlock
      veRoundsβ‘ : vRound    v β‘ bRound veBlock
 open VotesForBlock

 module _ {β}(π’ : IntermediateSystemState β) where
  open IntermediateSystemState π’
  open All-InSys-props InSys

  ---------------------
  -- * PreferredRound * --
  ---------------------

  -- The PreferredRound rule is a little more involved to be expressed in terms
  -- of /HasBeenSent/: it needs two additional pieces which are introduced
  -- next.

  -- Cand-3-chain v carries the information for estabilishing
  -- that v.proposed will be part of a 3-chain if a QC containing v is formed.
  -- The difficulty is that we can't easily access the "grandparent" of a vote.
  -- Instead, we must explicitly state that it exists.
  --
  --                                candidate 3-chain
  --       +------------------------------------------------------+
  --       |                                                      |
  --       |       2-chain                                        |
  --       +----------------------------------+
  --  β― <- v.grandparent <- qβ <- v.parent <- q <- v.proposed  <- v
  --                                          Μ­
  --                                          |
  --                                     The 'qc' defined below is an
  --                                     abstract view of q, above.
  record Cand-3-chain-vote (v : Vote) : Set β where
     constructor mkCand3chainvote
     field
       votesForB : VotesForBlock v
       c3Blkβsys : InSys (B (veBlock votesForB))
       qc        : QC
       qcβb      : Q qc β B (veBlock votesForB)
       rc        : RecordChain (Q qc)
       rcβsys    : All-InSys rc
       n         : β
       is-2chain : π-chain Contig (2 + n) rc
  open Cand-3-chain-vote public

  v-cand-3-chainβ0<roundv : β {v} β Cand-3-chain-vote v β 0 < vRound v
  v-cand-3-chainβ0<roundv
    record { votesForB = (mkVE veBlockβ veIdβ refl)
           ; qc = qc
           ; qcβb = qcβb
           ; rc = rc
           ; n = n
           ; is-2chain = is-2chain }
    with qcβb
  ... | QβB (sβ€s x) xβ = sβ€s zβ€n

   -- Returns the round of the head of the candidate 3-chain. In the diagram
   -- explaining Cand-3-chain-vote, this would be v.grandparent.round.
  Cand-3-chain-head-round : β{v} β Cand-3-chain-vote v β Round
  Cand-3-chain-head-round c3cand =
     getRound (kchainBlock (suc zero) (is-2chain c3cand))

 module _ {β}(π’ : IntermediateSystemState β) where
  open IntermediateSystemState π’
  open All-InSys-props InSys

   -- The preferred round rule states a fact about the /previous round/
   -- of a vote; that is, the round of the parent of the block
   -- being voted for; the implementation will have to
   -- show it can construct this parent.
  data VoteParentData-BlockExt : Record β Set β where
     vpParentβ‘I : VoteParentData-BlockExt I
     vpParentβ‘Q : β{b q} β B b β Q q β InSys (B b) β VoteParentData-BlockExt (Q q)

   -- TODO-2: it may be cleaner to specify this as a RC 2 vpParent vpQC,
   -- and we should consider it once we address the issue in
   -- Abstract.RecordChain (below the definition of transp-π-chain)

  record VoteParentData (v : Vote) : Set β where
    field
      vpV4B        : VotesForBlock v
      vpBlockβsys  : InSys (B (veBlock vpV4B))
      vpParent     : Record
      vpParentβsys : InSys vpParent
      vpExt        : vpParent β B (veBlock vpV4B)
      vpMaybeBlock : VoteParentData-BlockExt vpParent
  open VoteParentData public

  -- The setup for PreferredRoundRule is like that for VotesOnce.
  -- Given two votes by an honest author Ξ±:
  Type : Set β
  Type = β{Ξ± v v'}
       β Meta-Honest-Member Ξ±
       β vMember v  β‘ Ξ± β HasBeenSent v
       β vMember v' β‘ Ξ± β HasBeenSent v'
       -- If v is a vote on a candidate 3-chain, that is, is a vote on a block
       -- that extends a 2-chain,
       β (c2 : Cand-3-chain-vote π’ v)
       -- and the round of v is lower than that of v',
       β vRound v < vRound v'
       ------------------------------
       -- then Ξ± obeyed the preferred round rule:
       β Ξ£ (VoteParentData v')
           (Ξ» vp β Cand-3-chain-head-round π’ c2 β€ round (vpParent vp))

  private
   make-cand-3-chain : β{n Ξ± q}{rc : RecordChain (Q q)}
                     β All-InSys rc
                     β (c3 : π-chain Contig (3 + n) rc)
                     β (v  : Ξ± βQC q)
                     β Cand-3-chain-vote π’ (βQC-Vote q v)
   make-cand-3-chain {q = q} ais (s-chain {suc (suc n)} {rc = rc} {b = b} extβ@(QβB h0 refl) _ extβ@(BβQ h1 refl) c2) v
     with c2
   ...| (s-chain {q = qβ} _ _ _ _)
       = record { votesForB = mkVE b (All-lookup (qVotes-C2 q) (Any-lookup-correct v))
                                     (trans (All-lookup (qVotes-C3 q) (Any-lookup-correct v)) h1)
                ; c3Blkβsys = All-InSysβlast-InSys (All-InSys-unstep ais)
                ; qc = qβ
                ; qcβb = extβ
                ; rc = rc
                ; rcβsys =  All-InSys-unstep (All-InSys-unstep ais)
                ; n  = n
                ; is-2chain = c2
                }

   -- It is important that the make-cand-3-chain lemma doesn't change the head of
   -- the 3-chain/cand-2-chain.
   make-cand-3-chain-lemma
     : β{n Ξ± q}{rc : RecordChain (Q q)} β (ais : All-InSys rc)
     β (c3 : π-chain Contig (3 + n) rc)
     β (v  : Ξ± βQC q)
     β kchainBlock (suc zero) (is-2chain (make-cand-3-chain ais c3 v)) β‘ kchainBlock (suc (suc zero)) c3
   make-cand-3-chain-lemma {q = q} aisβ c3@(s-chain {suc (suc n)} {rc = rc} {b = b} extβ@(QβB h0 refl) _ extβ@(BβQ h1 refl) c2) v
     with c2
   ...| (s-chain {q = qβ} _ _ _ (s-chain _ _ _ c)) = refl

   vdParent-prevRound-lemma
      : β{Ξ± q}(rc : RecordChain (Q q)) β (All-InSys rc) β (va : Ξ± βQC q)
      β (vp : VoteParentData (βQC-Vote q va))
        -- These properties are still about abstract records, so we could still cook up a trivial
        -- proof.  Therefore, if we need these properties, we need to connect the collision to
        -- Records that are InSys
      β NonInjective-β‘-pred (InSys β B) bId β (round (vpParent vp) β‘ prevRound rc)
   vdParent-prevRound-lemma {q = q} (step {r = B b} (step rc y) x@(BβQ refl refl)) ais va vp
     with b βBlock (veBlock (vpV4B vp))
   ...| no imp = injβ (((b , veBlock (vpV4B vp))
                      , (imp , (id-Bβ¨Q-inj (cong id-Bβ¨Q (trans (sym (All-lookup (qVotes-C2 q) (βQC-Vote-correct q va)))
                                                               (veId (vpV4B vp)))))))
                      , (ais (there x here) , (vpBlockβsys vp)))
   ...| yes refl
     with β-inj y (vpExt vp)
   ...| bSameId'
     with y | vpExt vp
   ...| IβB y0 y1   | IβB e0 e1   = injβ refl
   ...| QβB y0 refl | QβB e0 refl
     with vpMaybeBlock vp
   ...| vpParentβ‘Q {b = bP} bPβqP bpβSys
     with rc
   ...| step {r = B b'} rc' bβq
     with b' βBlock bP
   ...| no  imp = injβ (((b' , bP)
                       , (imp , (id-Bβ¨Q-inj (lemmaS1-2 (eq-Q refl) bβq bPβqP))))
                       , (ais (there x (there (QβB y0 refl) (there bβq here)))
                         , bpβSys))
   ...| yes refl
     with bPβqP | bβq
   ...| BβQ refl refl | BβQ refl refl = injβ refl

  -- Finally, we can prove the preferred round rule from the global version;
  proof : Type β PreferredRoundRule InSys
  proof glob-inv Ξ± hΞ± {q} {q'} {rc} aisβ c3 va {rc'} aisβ va' hyp
    with All-InSysβlast-InSys aisβ | All-InSysβlast-InSys aisβ
  ...| qβsys   | q'βsys
    with βQCβHasBeenSent qβsys  hΞ± va
       | βQCβHasBeenSent q'βsys hΞ± va'
  ...| sent-cv | sent-cv'
    with make-cand-3-chain aisβ c3  va | inspect
        (make-cand-3-chain aisβ c3) va
  ...| cand | [ R ]
    with glob-inv hΞ±
           (sym (βQC-Member q  va )) sent-cv
           (sym (βQC-Member q' va')) sent-cv'
           cand hyp
  ...| va'Par , res
    with vdParent-prevRound-lemma rc' aisβ va' va'Par
  ...| injβ hb    = injβ hb
  ...| injβ final
    with make-cand-3-chain-lemma aisβ c3 va
  ...| xx = injβ (substβ _β€_
                   (cong bRound (trans (cong (kchainBlock (suc zero) β is-2chain) (sym R)) xx))
                   final
                   res)

