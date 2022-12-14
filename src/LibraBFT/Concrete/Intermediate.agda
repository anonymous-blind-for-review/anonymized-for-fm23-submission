{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2020, 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}
-- This module defines an intermediate (between an implementation and Abstract) notion
-- of a system state.  The goal is to enable proving for a particular implementation
-- the properties required to provide to Abstract.Properties in order to get the high
-- level correctness conditions, while moving the obligations for the implementation
-- closer to notions more directly provable for an implementation.

open import LibraBFT.ImplShared.Base.Types
open import Util.Prelude

open import LibraBFT.Abstract.Types.EpochConfig UID NodeId
open WithAbsVote

module LibraBFT.Concrete.Intermediate
    (π : EpochConfig)
    (π₯ : VoteEvidence π)
   where
   open import LibraBFT.Abstract.Abstract UID _βUID_ NodeId π π₯

   -- Since the invariants we want to specify (votes-once and preferred-round-rule),
   -- are predicates over a /System State/, we must factor out the necessary
   -- functionality.
   --
   -- An /IntermediateSystemState/ supports a few different notions; namely,
   record IntermediateSystemState (β : Level) : Set (β+1 β) where
     field
       -- A notion of membership of records
       InSys : Record β Set β

       -- A predicate about whether votes have been transfered
       -- amongst participants
       HasBeenSent : Vote β Set β

       -- Such that, the votes that belong to honest participants inside a
       -- QC that exists in the system must have been sent
       βQCβHasBeenSent : β{q Ξ±} β InSys (Q q) β Meta-Honest-Member Ξ±
                       β (va : Ξ± βQC q) β HasBeenSent (βQC-Vote q va)
   open IntermediateSystemState
