{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

open import LibraBFT.Impl.OBM.Rust.Duration as Duration
open import LibraBFT.ImplShared.Consensus.Types.EpochIndep
open import Util.Prelude

module LibraBFT.Impl.OBM.Time where

postulate -- TODO-1 : iPlus, timeT
  iPlus : Instant → Duration → Instant
  timeT : Instant
