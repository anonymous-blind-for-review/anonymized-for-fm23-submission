{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2020, 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

open import LibraBFT.ImplShared.Base.Types

open import LibraBFT.Abstract.Types.EpochConfig UID NodeId
open import LibraBFT.Concrete.System
open import LibraBFT.Concrete.System.Parameters
open import LibraBFT.Concrete.Obligations
open import LibraBFT.ImplShared.Consensus.Types
open import LibraBFT.ImplShared.Consensus.Types.EpochDep
open import Util.Prelude

open        EpochConfig
open import Yasm.Base
open import Yasm.System β-RoundManager β-VSFP ConcSysParms

-- In this module, we assume that the implementation meets its
-- obligations, and use this assumption to prove that, in any reachable
-- state, the implementatioon enjoys one of the per-epoch correctness
-- conditions proved in Abstract.Properties.  It can be extended to other
-- properties later.
module LibraBFT.Concrete.Properties
         (iiah         : SystemInitAndHandlers β-RoundManager ConcSysParms)
         (st           : SystemState)
         (r            : WithInitAndHandlers.ReachableSystemState iiah st)
         (π           : EpochConfig)
         (π-βsys       : ParamsWithInitAndHandlers.EpochConfigβSys iiah st π)
         (impl-correct : ImplObligations iiah π)
         where

  open WithEC
  open import LibraBFT.Abstract.Abstract     UID _βUID_ NodeId π (ConcreteVoteEvidence π) as Abs
  open import LibraBFT.Concrete.Intermediate                   π (ConcreteVoteEvidence π)
  import      LibraBFT.Concrete.Obligations.VotesOnce          π (ConcreteVoteEvidence π) as VO-obl
  import      LibraBFT.Concrete.Obligations.PreferredRound     π (ConcreteVoteEvidence π) as PR-obl
  open import LibraBFT.Concrete.Properties.VotesOnce                                       as VO
  open import LibraBFT.Concrete.Properties.PreferredRound                                  as PR
  open import LibraBFT.ImplShared.Util.HashCollisions iiah

  open        ImplObligations impl-correct
  open        PerEpoch π
  open        PerState st
  open        PerReachableState r

  {- Although the `Concrete` modules are currently specified in terms of the implementation types used by
     the implementation we are proving correct, the important aspect of the `Concrete` modules is to
     reduce implementation obligations specified in the `Abstract` modules to being about `Vote`s sent.
     These properties are stated in terms of an `IntermediateSystemState`, which is derived from a
     `ReachableSystemState` for an implementation-specific system configuration.

     The `Concrete` modules could be refactored to enable verifying a broader range of implementations,
     including those that use entirely different implementation types.  In more detail, the `Concrete`
     modules would be parameterized by (at least):

       - `SystemTypeParameters`;
       - `SystemInitAndHandlers`;
       - a predicate to satisy the requirements of PeerCanSignForPK, and a proof that it is stable
       - a function from a `ReachableSystemState` of a system instantiated with
         the provided `SystemTypeParameters` to an `IntermediateSystemState`;
       - proof that the `InSys` predicate is stable for the given types (i.e., if a Record is InSys
         according to the IntermediateSystemState for the prestate of a transition, then it is also
         InSys according to the IntermediateSystemState for the poststate of that transition.
       - an implementation Vote type
       - machinery for accessing signatures of Votes, and for deriving abstract Votes from them
       - proof that two Votes with the same signature represent the same abstract vote
       - ...

     This will also break existing proofs and require them to be reworked in terms of these module
     parameters.

     TODO-NOT-DO: Refactor Concrete so that it is independent of implementation types, thus making
     it more general for a wider range of implementations.  As our main motivation is verifying an
     implementation (and perhaps variations on it) that use the same types, we do not consider it
     worthwhile at this time.
  -}

  open        IntermediateSystemState intSystemState

  -- This module parameter asserts that there are no hash collisions between Blocks *in the system*,
  -- allowing us to eliminate that case when the abstract properties claim it is the case.
  module _ (no-collisions-InSys : NoCollisions InSys) where

    --------------------------------------------------------------------------------------------
    -- * A /ValidSysState/ is one in which both peer obligations are obeyed by honest peers * --
    --------------------------------------------------------------------------------------------

    record ValidSysState {β}(π’ : IntermediateSystemState β) : Set (β+1 β0 ββ β) where
      field
        vss-votes-once      : VO-obl.Type π’
        vss-preferred-round : PR-obl.Type π’
    open ValidSysState public

    validState : ValidSysState intSystemState
    validState = record
      { vss-votes-once      = VO.Proof.voo iiah π sps-cor bsvc bsvr vβ’0 βBI? iro      voβ     r
      ; vss-preferred-round = PR.Proof.prr iiah π sps-cor bsvr      vβ’0 βBI? v4rc iro prβ prβ r π-βsys
      }

    open All-InSys-props InSys
    open WithAssumptions InSys no-collisions-InSys

    -- We can now invoke the various abstract correctness properties.  Note that the arguments are
    -- expressed in Abstract terms (RecordChain, CommitRule).  Proving the corresponding properties
    -- for the actual implementation will involve proving that the implementation decides to commit
    -- only if it has evidence of the required RecordChains and CommitRules such that the records in
    -- the RecordChains are all "InSys" according to the implementation's notion thereof (defined in
    -- Concrete.System.intSystemState).
    ConcCommitsDoNotConflict :
       β{q q'}
       β {rc  : RecordChain (Abs.Q q)}  β All-InSys rc
       β {rc' : RecordChain (Abs.Q q')} β All-InSys rc'
       β {b b' : Abs.Block}
       β CommitRule rc  b
       β CommitRule rc' b'
       β (Abs.B b) βRC rc' β (Abs.B b') βRC rc
    ConcCommitsDoNotConflict =
      CommitsDoNotConflict
        (VO-obl.proof intSystemState (vss-votes-once validState))
        (PR-obl.proof intSystemState (vss-preferred-round validState))

    module _ (βQCβAllSent : Complete InSys) where

      ConcCommitsDoNotConflict'
        : β{o o' q q'}
        β {rcf  : RecordChainFrom o  (Abs.Q q)}  β All-InSys rcf
        β {rcf' : RecordChainFrom o' (Abs.Q q')} β All-InSys rcf'
        β {b b' : Abs.Block}
        β CommitRuleFrom rcf  b
        β CommitRuleFrom rcf' b'
        β   Ξ£ (RecordChain (Abs.Q q')) ((Abs.B b)  βRC_)
          β Ξ£ (RecordChain (Abs.Q q))  ((Abs.B b') βRC_)
      ConcCommitsDoNotConflict' =
        CommitsDoNotConflict'
          (VO-obl.proof intSystemState (vss-votes-once validState))
          (PR-obl.proof intSystemState (vss-preferred-round validState))
          βQCβAllSent
