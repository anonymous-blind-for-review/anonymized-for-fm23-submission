{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

open import LibraBFT.Base.Types
open import LibraBFT.Impl.OBM.Logging.Logging
import      LibraBFT.Impl.Types.LedgerInfoWithSignatures as LIWS
open import LibraBFT.ImplShared.Consensus.Types
open import Optics.All
open import Util.Prelude

module LibraBFT.Impl.Types.EpochState where

verify : EpochState → LedgerInfoWithSignatures → Either ErrLog Unit
verify self ledgerInfo = do
  lcheck (self ^∙ esEpoch == ledgerInfo ^∙ liwsLedgerInfo ∙ liEpoch)
         ( "EpochState" ∷ "LedgerInfo has unexpected epoch" ∷ [])
         --, show (self^.esEpoch), show (ledgerInfo^.liwsLedgerInfo.liEpoch) ]
  LIWS.verifySignatures ledgerInfo (self ^∙ esVerifier)

epochChangeVerificationRequired : EpochState → Epoch → Bool
epochChangeVerificationRequired self epoch = ⌊ self ^∙ esEpoch <? epoch ⌋

isLedgerInfoStale : EpochState → LedgerInfo → Bool
isLedgerInfoStale self ledgerInfo = ⌊ ledgerInfo ^∙ liEpoch <? self ^∙ esEpoch ⌋
