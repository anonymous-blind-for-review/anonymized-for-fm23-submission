{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

open import LibraBFT.Base.Types
import      LibraBFT.Impl.Types.EpochState      as EpochState
import      LibraBFT.Impl.Types.Waypoint        as Waypoint
open import LibraBFT.ImplShared.Consensus.Types
open import Util.Encode
open import Util.PKCS                           hiding (verify)
open import Util.Prelude

module LibraBFT.Impl.Types.Verifier where

record Verifier (A : Set) : Set where
  field
    verify                          : A → LedgerInfoWithSignatures → Either ErrLog Unit
    epochChangeVerificationRequired : A → Epoch                    → Bool
    isLedgerInfoStale               : A → LedgerInfo               → Bool
    ⦃ encodeA ⦄                     : Encoder A

open Verifier ⦃ ... ⦄ public

instance
  VerifierEpochState : Verifier EpochState
  VerifierEpochState = record
    { verify                          = EpochState.verify
    ; epochChangeVerificationRequired = EpochState.epochChangeVerificationRequired
    ; isLedgerInfoStale               = EpochState.isLedgerInfoStale
    }

instance
  VerifierWaypoint   : Verifier Waypoint
  VerifierWaypoint   = record
    { verify                          = Waypoint.verifierVerify
    ; epochChangeVerificationRequired = Waypoint.epochChangeVerificationRequired
    ; isLedgerInfoStale               = Waypoint.isLedgerInfoStale
    }

