{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2020, 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

open import LibraBFT.ImplShared.Base.Types

open import LibraBFT.Abstract.Types.EpochConfig UID NodeId
open import LibraBFT.Concrete.Records as LCR
open import LibraBFT.Concrete.System
open import LibraBFT.Concrete.System.Parameters
open import LibraBFT.ImplShared.Consensus.Types
open import LibraBFT.ImplShared.Consensus.Types.EpochDep
open import LibraBFT.ImplShared.Util.Crypto
open import Optics.All
open import Util.KVMap
open import Util.Lemmas
open import Util.PKCS
open import Util.Prelude
open import Yasm.Base

open        EpochConfig

-- This module contains placeholders for the future analog of the
-- corresponding VotesOnce property.  Defining the implementation
-- obligation and proving that it is an invariant of an implementation
-- is a substantial undertaking.  We are working first on proving the
-- simpler VotesOnce property to settle down the structural aspects
-- before tackling the harder semantic issues.
module LibraBFT.Concrete.Properties.PreferredRound (iiah : SystemInitAndHandlers â-RoundManager ConcSysParms) (ð : EpochConfig) where
 open        LibraBFT.ImplShared.Consensus.Types.EpochDep.WithEC
 import      LibraBFT.Abstract.Records         UID _âUID_ NodeId ð (ConcreteVoteEvidence ð) as Abs
 import      LibraBFT.Abstract.Records.Extends UID _âUID_ NodeId ð (ConcreteVoteEvidence ð) as Ext
 open import LibraBFT.Abstract.RecordChain     UID _âUID_ NodeId ð (ConcreteVoteEvidence ð)
 open import LibraBFT.Abstract.System          UID _âUID_ NodeId ð (ConcreteVoteEvidence ð)
 open import LibraBFT.Concrete.Intermediate                      ð (ConcreteVoteEvidence ð)
 open import LibraBFT.Concrete.Obligations.PreferredRound        ð (ConcreteVoteEvidence ð)
 open        SystemTypeParameters ConcSysParms
 open        SystemInitAndHandlers iiah
 open        ParamsWithInitAndHandlers iiah
 open import LibraBFT.ImplShared.Util.HashCollisions iiah
 open import LibraBFT.Concrete.Properties.Common iiah ð
 open import Yasm.Yasm â-RoundManager â-VSFP ConcSysParms iiah PeerCanSignForPK PeerCanSignForPK-stable

 open PerEpoch    ð
 open WithAbsVote ð
 open LCR.WithEC  ð
 open PerState
 open PerReachableState
 open IntermediateSystemState
 open All-InSys-props

 Block-RC-AllInSys : Abs.Vote â SystemState â Set
 Block-RC-AllInSys vabs st = â[ b ] ( Abs.bId b â¡ abs-vBlockUID vabs
                                    Ã Î£ (RecordChain (Abs.B b)) (All-InSys (InSys (intSystemState st))))

 ImplObligation-RC : Set (â+1 â-RoundManager)
 ImplObligation-RC =
   â{pid s' outs pk}{pre : SystemState}
   â ReachableSystemState pre
   -- For any honest call to /handle/ or /init/,
   â (sps : StepPeerState pid (msgPool pre) (initialised pre) (peerStates pre pid) (s' , outs))
   â â{v m} â Meta-Honest-PK pk
   -- For signed every vote v of every outputted message
   â v âMsg m â send m â outs
   â (sig : WithVerSig pk v)
   â 0 < v ^â vRound
   â Â¬ (MsgWithSigâ pk (ver-signature sig) (msgPool pre))
   â let post = StepPeer-post {pre = pre} (step-honest sps)
     in (pcs4 : PeerCanSignForPK post v pid pk)
        â â[ mbr ] ( getPubKey ð mbr â¡ pk
                   Ã Block-RC-AllInSys (Î±-ValidVote ð v mbr) post)

 -- For PreferredRound, we have two implementation obligations, one for when v is sent by the
 -- step and v' has been sent before, and one for when both are sent by the step.
 ImplObligationâ : Set (â+1 â-RoundManager)
 ImplObligationâ =
   â{pid pid' s' outs pk}{pre : SystemState}
   â (r : ReachableSystemState pre)
   -- For any honest call to /handle/ or /init/,
   â (sps : StepPeerState pid (msgPool pre) (initialised pre) (peerStates pre pid) (s' , outs))
   â let post = StepPeer-post {pre = pre} (step-honest sps) in
     â{mbr v vabs m v' v'abs m'}
   â Meta-Honest-PK pk
   -- For signed every vote v of every outputted message
   â v'  âMsg m'  â send m' â outs
   â (sig' : WithVerSig pk v') â Â¬ (âBootstrapInfo bootstrapInfo (ver-signature sig'))
   -- If v is really new and valid
   â Â¬ (MsgWithSigâ pk (ver-signature sig') (msgPool pre))
   â PeerCanSignForPK (StepPeer-post {pre = pre} (step-honest sps)) v' pid pk
   -- And if there exists another v' that has been sent before
   â v âMsg m â (pid' , m) â (msgPool pre)
   â (sig : WithVerSig pk v) â Â¬ (âBootstrapInfo bootstrapInfo (ver-signature sig))
   -- If v and v' share the same epoch
   â v ^â  vEpoch â¡ v' ^â vEpoch
   -- and v is for a smaller round
   â v ^â vRound < v' ^â vRound
   -- and vabs* are the abstract Votes for v and v'
   â Î±-ValidVote ð v  mbr â¡ vabs
   â Î±-ValidVote ð v' mbr â¡ v'abs
   â (c2 : Cand-3-chain-vote (intSystemState post) vabs)
   -- then the round of the block that v' votes for is at least the round of
   -- the grandparent of the block that v votes for (i.e., the preferred round rule)
   â Î£ (VoteParentData (intSystemState post) v'abs)
           (Î» vp â Cand-3-chain-head-round (intSystemState post) c2 â¤ Abs.round (vpParent vp))
     â (VoteForRoundâ pk (v' ^â vRound) (v' ^â vEpoch) (v' ^â vProposedId) (msgPool pre))

 -- Similarly in case the same step sends both v and v'
 ImplObligationâ : Set (â+1 â-RoundManager)
 ImplObligationâ =
   â{pid s' outs pk}{pre : SystemState}
   â (r  : ReachableSystemState pre)
   -- For any honest call to /handle/ or /init/,
   â (sps : StepPeerState pid (msgPool pre) (initialised pre) (peerStates pre pid) (s' , outs))
   â let post = StepPeer-post {pre = pre} (step-honest sps) in
     â{mbr v vabs m v' v'abs m'}
   â Meta-Honest-PK pk
   -- For every vote v represented in a message output by the call
   â v  âMsg m  â send m â outs
   â (sig : WithVerSig pk v) â Â¬ (âBootstrapInfo bootstrapInfo (ver-signature sig))
   -- If v is really new and valid
   â Â¬ (MsgWithSigâ pk (ver-signature sig) (msgPool pre))
   â PeerCanSignForPK post v pid pk
   -- And if there exists another v' that is also new and valid
   â v' âMsg m'  â send m' â outs
   â (sig' : WithVerSig pk v') â Â¬ (âBootstrapInfo bootstrapInfo (ver-signature sig'))
   â Â¬ (MsgWithSigâ pk (ver-signature sig') (msgPool pre))
   â PeerCanSignForPK (StepPeer-post {pre = pre} (step-honest sps)) v' pid pk
   -- If v and v' share the same epoch and round
   â v ^â vEpoch â¡ v' ^â vEpoch
   â v ^â vRound < v' ^â vRound
   â Î±-ValidVote ð v  mbr â¡ vabs
   â Î±-ValidVote ð v' mbr â¡ v'abs
   â (c2 : Cand-3-chain-vote (intSystemState post) vabs)
   â Î£ (VoteParentData (intSystemState post) v'abs)
           (Î» vp â Cand-3-chain-head-round (intSystemState post) c2 â¤ Abs.round (vpParent vp))

 module _ where
   open InSys iiah

   stepPreservesVoteParentData : â {st0 st1 v}
     â Step st0 st1
     â (vpd : VoteParentData (intSystemState st0) v)
     â Î£ (VoteParentData (intSystemState st1) v)
         Î» vpd' â vpParent vpd' â¡ vpParent vpd
   stepPreservesVoteParentData {st0} {st1} theStep vpd
      with vpd
   ...| (record { vpV4B        = vpV4B
                ; vpBlockâsys  = vpBlockâsys
                ; vpParent     = vpParent
                ; vpParentâsys = vpParentâsys
                ; vpExt        = vpExt
                ; vpMaybeBlock = vpMaybeBlock
                }) = (record
                     { vpV4B        = vpV4B
                     ; vpBlockâsys  = stable theStep vpBlockâsys
                     ; vpParent     = vpParent
                     ; vpParentâsys = stable theStep vpParentâsys
                     ; vpExt        = vpExt
                     ; vpMaybeBlock = transp-vpmb vpMaybeBlock
                     }) , refl
     where transp-vpmb : â {r}
                         â VoteParentData-BlockExt (intSystemState st0) r
                         â VoteParentData-BlockExt (intSystemState st1) r
           transp-vpmb vpParentâ¡I = vpParentâ¡I
           transp-vpmb (vpParentâ¡Q x xâ) = vpParentâ¡Q x (stable theStep xâ)

 module Proof
   (sps-corr   : StepPeerState-AllValidParts)   -- Bring in newMsgâmsgSentB4
   (Impl-bsvr  : ImplObl-bootstrapVotesRoundâ¡0)
   (Impl-nvrâ¢0 : ImplObl-NewVoteRoundâ¢0)
   (Impl-âBI?  : (sig : Signature) â Dec (âBootstrapInfo bootstrapInfo sig))
   (Impl-RC    : ImplObligation-RC)
   (Impl-IRO   : IncreasingRoundObligation)
   (Impl-PR1   : ImplObligationâ)
   (Impl-PR2   : ImplObligationâ)
    where
  module _ {st : SystemState}(r : ReachableSystemState st) (ð-âsys : EpochConfigâSys st ð) where
   open        Structural sps-corr
   open        ConcreteCommonProperties st r sps-corr Impl-bsvr Impl-nvrâ¢0

   Î±-ValidVote-trans : â {pk mbr vabs pool} (v : Vote)
                     â Î±-ValidVote ð v mbr â¡ vabs
                     â (vfr : VoteForRoundâ pk (v ^â vRound) (v ^â vEpoch)
                                            (v ^â vProposedId) pool)
                     â Î±-ValidVote ð (msgVote vfr) mbr â¡ vabs
   Î±-ValidVote-trans vâ refl vfr
     with msgRoundâ¡ vfr | msgEpochâ¡ vfr | msgBIdâ¡ vfr
   ...| refl | refl | refl = refl

   0<rndâÂ¬BootStrap : â {pk rnd bid pool}
                      â (v4r : VoteForRoundâ pk rnd (epoch ð) bid pool)
                      â 0 < rnd
                      â Â¬ (âBootstrapInfo bootstrapInfo (ver-signature $ msgSigned v4r))
   0<rndâÂ¬BootStrap v4r 0<r rewrite sym (msgRoundâ¡ v4r) = â¥-elim â (<ââ¢ 0<r) â sym â Impl-bsvr (msgSigned v4r)

   -- To prove this, we observe that cheaters can't introduce a VoteForRoundâ for an honest PK.  We
   -- will also require an additional implementation obligation.  It may simply be that Votes sent
   -- satisy IsValidVote, but the question is where do we maintain evidence that such a RecordChain
   -- exists for any Block we may vote for?
   voteForRound-RC : â {pk vabs}{st : SystemState}
                     â Meta-Honest-PK pk
                     â ReachableSystemState st
                     â (v4r : VoteForRoundâ pk (abs-vRound vabs) (epoch ð) (abs-vBlockUID vabs) (msgPool st))
                     â 0 < abs-vRound vabs
                     â Block-RC-AllInSys vabs st

   voteForRound-RC-mws : â {pk vabs pre pid st' outs}
                       â Meta-Honest-PK pk
                       â ReachableSystemState pre
                       â (sp : StepPeer pre pid st' outs)
                       â (v4r : VoteForRoundâ pk (abs-vRound vabs) (epoch ð) (abs-vBlockUID vabs) (msgPool $ StepPeer-post sp))
                       â MsgWithSigâ pk (ver-signature $ msgSigned v4r) (msgPool pre)
                       â 0 < abs-vRound vabs
                       â Block-RC-AllInSys vabs (StepPeer-post sp)
   voteForRound-RC-mws {pk} {vabs} {pre} hpk preReach sps v4r mwsb4 0<r
      with sameSigâsameVoteData (msgSigned mwsb4) (msgSigned v4r) (msgSameSig mwsb4)
   ...| injâ hb = â¥-elim $ meta-no-collision preReach hb -- TODO-2: refine sameSigâsamevotedata to
                                                         -- enable tying collision to specific state
                                                         -- so we can use meta-no-collision-in-sys
   ...| injâ svd
      with msgSentB4âVoteRoundâ (msgSigned v4r) mwsb4'
         where
           mwsb4' : _
           mwsb4' rewrite
                    trans (cong (_^â vdProposed â biEpoch) $ sym svd) (msgEpochâ¡ v4r) |
                    msgBIdâ¡ v4r |
                    msgSameSig mwsb4 = mwsb4
   ...| v4r' , refl
      with voteForRound-RC {pk} {vabs} hpk preReach v4r'' 0<r
         where
           v4r'' : VoteForRoundâ pk (abs-vRound vabs) (epoch ð) (abs-vBlockUID vabs) (msgPool pre)
           v4r'' rewrite sym (msgEpochâ¡ v4r) | sym (msgRoundâ¡ v4r) | sym (msgBIdâ¡ v4r) = v4r'
   ...| b , refl , rc , ais = b , refl , rc , InSys.ais-stable iiah (step-peer sps) rc ais

   voteForRound-RC {pk} {vabs} {st} hpk (step-s preReach (step-peer (step-honest sps))) v4r 0<r
      with newMsgâmsgSentB4 {sndr = msgSender v4r} preReach sps hpk (msgSigned v4r)
                            (0<rndâÂ¬BootStrap v4r 0<r)
                            (msgâ v4r)
                            (msgâpool v4r)
   ...| injâ mwsb4 = voteForRound-RC-mws {vabs = vabs} hpk preReach (step-honest sps) v4r mwsb4 0<r
   ...| injâ (sendâouts , pcs4 , Â¬sentb4) rewrite sym (msgRoundâ¡ v4r)
      with Impl-RC preReach sps hpk (msgâ v4r) sendâouts (msgSigned v4r) 0<r Â¬sentb4 pcs4
   ...| mbr , refl , b , bidâ¡ , rcâsys  = b , (trans bidâ¡ $ msgBIdâ¡ v4r) , rcâsys
   voteForRound-RC {pk} {vabs} {st} hpk (step-s {pre = pre} preReach (step-peer (step-cheat {pid} x))) v4r 0<r
      with VoteRoundââmsgSent v4r
   ...| msgb4 , refl , refl
      with Â¬cheatForgeNew {st = pre} (step-cheat x) refl unit hpk msgb4
                          (0<rndâÂ¬BootStrap v4r 0<r)
   ...| mwsb4 = voteForRound-RC-mws {vabs = vabs} hpk preReach (step-cheat x) v4r mwsb4 0<r

   open _Î±-Sent_
   open _BlockDataInjectivityProps_

   Abs2ImplCollision : â {ab1 ab2 : Abs.Block}{post}
                     â (rPost : ReachableSystemState post)
                     â InSys (intSystemState post) (Abs.B ab1)
                     â InSys (intSystemState post) (Abs.B ab2)
                     â ab1 â¢ ab2
                     â Abs.bId ab1 â¡ Abs.bId ab2
                     â HashCollisionFound rPost
   Abs2ImplCollision rPost (ws epâ¡1 m1âpool (bâNM {cb1} {pm1} refl refl bidcorr1))
                           (ws epâ¡2 m2âpool (bâNM {cb2} {pm2} refl refl bidcorr2)) neq absIdsâ¡ =
     msgmsgHC {r = rPost} (inP m1âpool (inPM (inB {b = cb1}))) (inP m2âpool (inPM (inB {b = cb2}))) hashesâ¡ bslsâ¢
     where
       -- TODO-2: Some of the properties should be factored out for reuse, maybe into Common?
       bIdsâ¡ : _
       bIdsâ¡ = trans (trans (Î±-Block-bidâ¡ cb1) absIdsâ¡) (sym (Î±-Block-bidâ¡ cb2))

       hashesâ¡ : _
       hashesâ¡ = trans (trans bidcorr1 bIdsâ¡) (sym bidcorr2)

       rndsâ¡ : â {cb1 cb2} â (cb1 ^â bBlockData) BlockDataInjectivityProps (cb2 ^â bBlockData)
               â Abs.bRound (Î±-Block cb1) â¡ Abs.bRound (Î±-Block cb2)
       rndsâ¡ {cb1} {cb2} injprops = trans (sym (Î±-Block-rndâ¡ cb1)) (trans (bdInjRound injprops) (Î±-Block-rndâ¡ cb2))

       propBlock : â {cb pm} â pm ^â pmProposal â¡ cb
                   â cb ^â bId â¡ pm ^â pmProposal â bId
       propBlock refl = refl

       prevQCsâ¡ : â {cb1 cb2}
                  â (cb1 ^â bBlockData) BlockDataInjectivityProps (cb2 ^â bBlockData)
                  â Abs.bPrevQC (Î±-Block cb1) â¡ Abs.bPrevQC (Î±-Block cb2)
       prevQCsâ¡ {cb1} {cb2} injprops
          with cb1 ^â bBlockData â bdBlockType | inspect
               (cb1 ^â_) (bBlockData â bdBlockType)
       ...| Genesis      | [ R ] rewrite R                    = sym (Î±-Block-prevqcâ¡-Gen  {cb2} (bdInjBTGen injprops R))
       ...| Proposal _ _ | [ R ] rewrite R | bdInjVD injprops = sym (Î±-Block-prevqcâ¡-Prop {cb2} (trans (sym $ bdInjBTProp injprops R) R))
       ...| NilBlock     | [ R ] rewrite R | bdInjBTNil injprops R | bdInjVD injprops = refl

       bslsâ¢ : _
       bslsâ¢ _
          with hashBD-inj hashesâ¡
       ...| injprops = neq (Abs.Block-Î·
                              (rndsâ¡ {cb1} {cb2} injprops)
                              absIdsâ¡
                              (prevQCsâ¡ {cb1} {cb2} injprops))

   Cand-3-chain-vote-b4 : â {pk vabs}{pre : SystemState}{pid st' outs sp}
                          â Meta-Honest-PK pk
                          â ReachableSystemState pre
                          â let post = StepPeer-post {pid}{st'}{outs}{pre} sp in
                            (c2 : Cand-3-chain-vote (intSystemState post) vabs)
                            â (v4r : VoteForRoundâ pk (abs-vRound vabs) (epoch ð) (abs-vBlockUID vabs) (msgPool pre))
                            â Î£ (Cand-3-chain-vote (intSystemState pre) vabs)
                                 Î» c2' â Cand-3-chain-head-round (intSystemState post) c2
                                       â¡ Cand-3-chain-head-round (intSystemState pre ) c2'
   Cand-3-chain-vote-b4 {pk} {vabs} {pre} {pid} {st'} {outs} {sp} pkH r
                        c3@(mkCand3chainvote (mkVE veBlock refl refl) c3Blkâsysâ qcâ qcâbâ rcâ rcâsysâ nâ is-2chainâ) v4r
      with v-cand-3-chainâ0<roundv  (intSystemState $ StepPeer-post {pid}{st'}{outs}{pre} sp)
   ...| 0<r
      with voteForRound-RC {vabs = vabs} pkH r v4r (0<r c3)
   ...| b , refl , rcb , ais
      with veBlock Abs.âBlock b
   ...| no   neq = â¥-elim (meta-no-collision-in-sys postR hcf)
        where
          post    = StepPeer-post sp
          theStep = step-peer sp
          postR   = step-s r theStep
          hcf = Abs2ImplCollision postR c3Blkâsysâ (InSys.stable iiah theStep (ais here)) neq refl
   ...| yes refl
      with RecordChain-irrelevant rcb (step rcâ qcâbâ)
   ...| injâ (((b1 , b2) , neq , absIdsâ¡) , b1ârcb , b2ârc1ext) = â¥-elim (meta-no-collision-in-sys postR (hcf b2ârc1ext))
      where
         post    = StepPeer-post sp
         theStep = step-peer sp
         postR   = step-s r theStep

         inSys1  = InSys.stable iiah theStep $ ais b1ârcb
         inSys2 : _ â _
         inSys2 here = c3Blkâsysâ
         inSys2 (there .qcâbâ b2ârc1ext) = rcâsysâ b2ârc1ext

         hcf : _ â _
         hcf b2ârc1ext = Abs2ImplCollision postR inSys1 (inSys2 b2ârc1ext) neq absIdsâ¡
   ...| injâ (eq-step {râ = .(Abs.B b)} {râ = .(Abs.B b)} rc0 rc1 bâb
                      ext0@(Ext.IâB _ prevNothing)
                      ext1@(Ext.QâB _ prevJust)
                      rcrestâ) = absurd just _ â¡ nothing case trans prevJust prevNothing of Î» ()
   ...| injâ (eq-step {râ = .(Abs.B b)} {râ = .(Abs.B b)} rc0 rc1 bâb
                      ext0@(Ext.QâB {qc0} {.b} _ _)
                      ext1@(Ext.QâB {qc1} {.b} _ _) rcrestâ) = newc3 , rndsâ¡
          where

            newc3 = mkCand3chainvote (mkVE b refl refl)
                                     (ais here)
                                     qc0
                                     ext0
                                     rc0
                                     (ais â (_âRC-simple_.there ext0))
                                     nâ
                                     (transp-ð-chain (âRC-sym rcrestâ) is-2chainâ)
            rndsâ¡ = cong Abs.bRound $ kchainBlock-âRC is-2chainâ (suc zero) (âRC-sym rcrestâ)

   PreferredRoundProof :
      â {pk roundâ roundâ bIdâ bIdâ vâabs vâabs mbr} {st : SystemState}
      â ReachableSystemState st
      â Meta-Honest-PK pk
      â (vâ : VoteForRoundâ pk roundâ (epoch ð) bIdâ (msgPool st))
      â (vâ : VoteForRoundâ pk roundâ (epoch ð) bIdâ (msgPool st))
      â roundâ < roundâ
      â Î±-ValidVote ð (msgVote vâ) mbr â¡ vâabs
      â Î±-ValidVote ð (msgVote vâ) mbr â¡ vâabs
      â (c3 : Cand-3-chain-vote (intSystemState st) vâabs)
      â Î£ (VoteParentData (intSystemState st) vâabs)
            (Î» vp â Cand-3-chain-head-round (intSystemState st) c3 â¤ Abs.round (vpParent vp))
   PreferredRoundProof {pk}{roundâ}{roundâ}{bIdâ}{bIdâ}{vâabs}{vâabs}{mbr}{st = post}
                       step@(step-s {pre = pre} r theStep) pkH vâ vâ râ<râ refl refl c3
      with msgRoundâ¡ vâ | msgEpochâ¡ vâ | msgBIdâ¡ vâ
         | msgRoundâ¡ vâ | msgEpochâ¡ vâ | msgBIdâ¡ vâ
   ...| refl | refl | refl | refl | refl | refl
      with Impl-âBI? (_vSignature (msgVote vâ)) | Impl-âBI? (_vSignature (msgVote vâ))
   ...| yes initâ  | yes initâ  = let rââ¡0 = Impl-bsvr (msgSigned vâ) initâ
                                      rââ¡0 = Impl-bsvr (msgSigned vâ) initâ
                                  in â¥-elim (<ââ¢ râ<râ (trans rââ¡0 (sym rââ¡0)))
   ...| yes initâ  | no  Â¬initâ = let 0â¡rv = sym (Impl-bsvr (msgSigned vâ) initâ)
                                      0<rv = v-cand-3-chainâ0<roundv (intSystemState post) c3
                                  in â¥-elim (<ââ¢ 0<rv 0â¡rv)
   ...| no  Â¬initâ | yes initâ  = let 0â¡râ = sym (Impl-bsvr (msgSigned vâ) initâ)
                                      râ   = msgVote vâ ^â vRound
                                  in â¥-elim (<ââ± râ<râ (subst (râ â¥_) 0â¡râ zâ¤n))
   ...| no  Â¬initâ | no Â¬initâ
      with theStep
   ...| step-peer {pid} {st'} {outs} cheat@(step-cheat c) = vpdPres
      where
              mâsb4 = Â¬cheatForgeNewSig r cheat unit pkH (msgSigned vâ) (msgâ vâ) (msgâpool vâ) Â¬initâ
              mâsb4 = Â¬cheatForgeNewSig r cheat unit pkH (msgSigned vâ) (msgâ vâ) (msgâpool vâ) Â¬initâ
              vâsb4 = msgSentB4âVoteRoundâ (msgSigned vâ) mâsb4
              vâsb4 = msgSentB4âVoteRoundâ (msgSigned vâ) mâsb4
              vâabs' = Î±-ValidVote-trans {pk} {mbr} {pool = msgPool pre} (msgVote vâ) refl (projâ vâsb4)
              vâabs' = Î±-ValidVote-trans {pk} {mbr} {pool = msgPool pre} (msgVote vâ) refl (projâ vâsb4)

              vpdPres : Î£ (VoteParentData (intSystemState post) vâabs)
                          (Î» vp â Cand-3-chain-head-round (intSystemState post) c3 â¤ Abs.round (vpParent vp))
              vpdPres
                 with Cand-3-chain-vote-b4 {sp = step-cheat c} pkH r c3 (projâ vâsb4)
              ...| c2' , c2'rndâ¡
                 with PreferredRoundProof r pkH (projâ vâsb4) (projâ vâsb4) râ<râ vâabs' vâabs' c2'
              ...| vpd , rndâ¤
                 with stepPreservesVoteParentData theStep vpd
              ...| res , rndsâ¡ rewrite sym rndsâ¡ = res , â¤-trans (â¤-reflexive c2'rndâ¡) rndâ¤
   ...| step-peer (step-honest stP)
      with â-mapâ (msgSentB4âVoteRoundâ (msgSigned vâ))
                  (newMsgâmsgSentB4 r stP pkH (msgSigned vâ) Â¬initâ  (msgâ vâ) (msgâpool vâ))
         | â-mapâ (msgSentB4âVoteRoundâ (msgSigned vâ))
                  (newMsgâmsgSentB4 r stP pkH (msgSigned vâ) Â¬initâ (msgâ vâ) (msgâpool vâ))
   ...| injâ (vâsb4 , refl) | injâ (vâsb4 , refl)
        = vpdPres
          where
            vâabs' = Î±-ValidVote-trans (msgVote vâ) refl vâsb4
            vâabs' = Î±-ValidVote-trans (msgVote vâ) refl vâsb4

            vpdPres : _
            vpdPres
               with Cand-3-chain-vote-b4 {sp = step-honest stP} pkH r c3 vâsb4
            ...| c2' , c2'rndâ¡
               with PreferredRoundProof r pkH vâsb4 vâsb4 râ<râ vâabs' vâabs' c2'
            ...| vpd , rndâ¤
               with stepPreservesVoteParentData theStep vpd
            ...| res , parsâ¡ rewrite sym parsâ¡ =  res , â¤-trans (â¤-reflexive c2'rndâ¡) rndâ¤
   ...| injâ (mââouts , vâpk , newVâ) | injâ (mââouts , vâpk , newVâ) =
              Impl-PR2 r stP pkH (msgâ vâ) mââouts (msgSigned vâ) Â¬initâ newVâ vâpk (msgâ vâ)
                                           mââouts (msgSigned vâ) Â¬initâ newVâ vâpk refl râ<râ refl refl c3

   ...| injâ (mââouts , vâpk , vâNew) | injâ (vâsb4 , refl) = help
        where
          roundâ¡ = trans (msgRoundâ¡ vâsb4) (msgRoundâ¡ vâ)
          Â¬bootstrapVâ = Â¬Bootstrapâ§Roundâ¡âÂ¬Bootstrap step pkH vâ Â¬initâ (msgSigned vâsb4) roundâ¡
          epochâ¡ = sym (msgEpochâ¡ vâsb4)

          implir0 : _
          implir0 = Impl-IRO r stP pkH (msgâ vâ) mââouts (msgSigned vâ) Â¬initâ vâNew vâpk (msgâ vâsb4)
                                       (msgâpool vâsb4)  (msgSigned vâsb4) Â¬bootstrapVâ epochâ¡

          help : _
          help = either (Î» râ<râ â â¥-elim (<ââ¯ râ<râ (<-transÊ³ (â¡ââ¤ (sym roundâ¡)) râ<râ)))
                        (Î» vâsb4 â let vâabs = Î±-ValidVote-trans (msgVote vâ) refl vâsb4
                                       vâabs = Î±-ValidVote-trans (msgVote vâ) refl vâsb4
                                       c2'p  = Cand-3-chain-vote-b4 {sp = step-honest stP} pkH r c3 vâsb4
                                       prp   = PreferredRoundProof r pkH vâsb4 vâsb4 râ<râ vâabs vâabs (projâ c2'p)
                                       vpd'  = stepPreservesVoteParentData theStep (projâ prp)
                                   in (projâ vpd') , (â¤-trans (â¤-reflexive (projâ c2'p)) (projâ prp)))
                        implir0
   ...| injâ (vâsb4 , refl)           | injâ (mââouts , vâpk , vâNew) = help
        where
          rvâ<râ = <-transÊ³ (â¡ââ¤ (msgRoundâ¡ vâsb4)) râ<râ
          roundâ¡ = trans (msgRoundâ¡ vâsb4) (msgRoundâ¡ vâ)
          Â¬bootstrapVâ = Â¬Bootstrapâ§Roundâ¡âÂ¬Bootstrap step pkH vâ Â¬initâ (msgSigned vâsb4) roundâ¡
          vâabs' = Î±-ValidVote-trans (msgVote vâ) refl vâsb4

          c2'p   = Cand-3-chain-vote-b4 {sp = step-honest stP} pkH r c3 vâsb4

          implir1 : _
          implir1 = Impl-PR1 r stP pkH (msgâ vâ) mââouts (msgSigned vâ) Â¬initâ vâNew vâpk
                                   (msgâ vâsb4) (msgâpool vâsb4) (msgSigned vâsb4) Â¬bootstrapVâ
                                   (msgEpochâ¡ vâsb4) rvâ<râ vâabs' refl c3

          help : _
          help = either id
                        (Î» vâsb4 â let vâabs' = Î±-ValidVote-trans (msgVote vâ) refl vâsb4
                                       prp    = PreferredRoundProof r pkH vâsb4 vâsb4 râ<râ vâabs' vâabs' (projâ c2'p)
                                       vpd'   = stepPreservesVoteParentData theStep (projâ prp)
                                   in (projâ vpd') , (â¤-trans (â¤-reflexive (projâ c2'p)) (projâ prp)))
                        implir1

   prr : Type (intSystemState st)
   prr honÎ± refl sv refl sv' c2 round<
     with vmsgâv (vmFor sv) | vmsgâv (vmFor sv')
   ...| refl | refl
       = let vâ = mkVoteForRoundâ (nm (vmFor sv)) (cv ((vmFor sv))) (cvânm (vmFor sv))
                                  (vmSender sv) (nmSentByAuth sv) (vmsgSigned (vmFor sv))
                                  (vmsgEpoch (vmFor sv)) refl refl
             vâ = mkVoteForRoundâ (nm (vmFor sv')) (cv (vmFor sv')) (cvânm (vmFor sv'))
                                  (vmSender sv') (nmSentByAuth sv') (vmsgSigned (vmFor sv'))
                                  (vmsgEpoch (vmFor sv')) refl refl
         in PreferredRoundProof r honÎ± vâ vâ round< refl refl c2
