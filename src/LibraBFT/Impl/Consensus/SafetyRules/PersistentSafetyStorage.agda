{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

------------------------------------------------------------------------------
import      LibraBFT.Impl.OBM.Crypto            as TODO
open import LibraBFT.Impl.OBM.Logging.Logging
open import LibraBFT.ImplShared.Consensus.Types
open import Optics.All
open import Util.PKCS
open import Util.Prelude
------------------------------------------------------------------------------
open import Data.String                         using (String)
------------------------------------------------------------------------------

module LibraBFT.Impl.Consensus.SafetyRules.PersistentSafetyStorage where

new : Author → Waypoint → SK → PersistentSafetyStorage
new author waypoint sk = mkPersistentSafetyStorage
     {- _pssSafetyData =-} (SafetyData∙new
                           {-  _sdEpoch          = Epoch-} 1
                           {-, _sdLastVotedRound = Round-} 0
                           {-, _sdPreferredRound = Round-} 0
                           {-, _sdLastVote       =-}       nothing)
     {-, _pssAuthor    =-} author
     {-, _pssWaypoint  =-} waypoint
     {-, _pssObmSK     =-} (just sk)

consensusKeyForVersion : PersistentSafetyStorage → PK → Either ErrLog SK
consensusKeyForVersion self pk =
  -- LBFT-OBM-DIFF
  maybeS (self ^∙ pssObmSK) (Left fakeErr {-"pssObmSK Nothing"-}) $ λ sk →
    if TODO.makePK sk /= pk
    then Left fakeErr -- ["sk /= pk"]
    else pure sk
 where
  here' : List String → List String
  here' t = "PersistentSafetyStorage" ∷ "consensusKeyForVersion" ∷ t
