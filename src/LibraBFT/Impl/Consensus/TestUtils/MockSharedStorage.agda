{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

open import LibraBFT.ImplShared.Consensus.Types
open import Optics.All
import      Util.KVMap                          as Map
open import Util.Prelude

module LibraBFT.Impl.Consensus.TestUtils.MockSharedStorage where

new : ValidatorSet → MockSharedStorage
new = mkMockSharedStorage
  Map.empty
  Map.empty
  Map.empty
  nothing
  nothing

newObmWithLIWS : ValidatorSet → LedgerInfoWithSignatures → MockSharedStorage
newObmWithLIWS vs obmLIWS =
  new vs & mssLis ∙~ Map.singleton (obmLIWS ^∙ liwsVersion) obmLIWS
