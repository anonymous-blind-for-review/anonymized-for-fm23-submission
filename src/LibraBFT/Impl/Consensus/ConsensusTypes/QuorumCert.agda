{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

open import LibraBFT.Base.Types
import      LibraBFT.Impl.Consensus.ConsensusTypes.VoteData as VoteData
open import LibraBFT.Impl.OBM.Logging.Logging
import      LibraBFT.Impl.Types.LedgerInfoWithSignatures    as LedgerInfoWithSignatures
open import LibraBFT.ImplShared.Base.Types
open import LibraBFT.ImplShared.Consensus.Types
open import Optics.All
open import Util.Hash
import      Util.KVMap                                      as Map
open import Util.Prelude
------------------------------------------------------------------------------
open import Data.String                                     using (String)

module LibraBFT.Impl.Consensus.ConsensusTypes.QuorumCert where

certificateForGenesisFromLedgerInfo : LedgerInfo → HashValue → QuorumCert
certificateForGenesisFromLedgerInfo ledgerInfo genesisId =
  let ancestor = BlockInfo∙new
                 (ledgerInfo ^∙ liEpoch + 1)
                 0
                 genesisId
                 (ledgerInfo ^∙ liTransactionAccumulatorHash)
                 (ledgerInfo ^∙ liVersion)
               --(ledgerInfo ^∙ liTimestamp)
                 nothing
      voteData = VoteData.new ancestor ancestor
      li       = LedgerInfo∙new ancestor (hashVD voteData)
   in QuorumCert∙new
      voteData
      (LedgerInfoWithSignatures∙new li Map.empty)

verify : QuorumCert → ValidatorVerifier → Either ErrLog Unit
verify self validator = do
  let voteHash = hashVD (self ^∙ qcVoteData)
  lcheck (self ^∙ qcSignedLedgerInfo ∙ liwsLedgerInfo ∙ liConsensusDataHash == voteHash)
         (here' ("Quorum Cert's hash mismatch LedgerInfo" ∷ []))
  if (self ^∙ qcCertifiedBlock ∙ biRound == 0)
    -- TODO-?: It would be nice not to require the parens around the do block
    then (do
      lcheck (self ^∙ qcParentBlock == self ^∙ qcCertifiedBlock)
             (here' ("Genesis QC has inconsistent parent block with certified block" ∷ []))
      lcheck (self ^∙ qcCertifiedBlock == self ^∙ qcLedgerInfo ∙ liwsLedgerInfo ∙ liCommitInfo)
             (here' ("Genesis QC has inconsistent commit block with certified block" ∷ []))
      lcheck (Map.kvm-size (self ^∙ qcLedgerInfo ∙ liwsSignatures) == 0)
             (here' ("Genesis QC should not carry signatures" ∷ []))
      )
    else do
      withErrCtx'
        ("fail to verify QuorumCert" ∷ [])
        (LedgerInfoWithSignatures.verifySignatures (self ^∙ qcLedgerInfo) validator)
      VoteData.verify (self ^∙ qcVoteData)
 where
  here' : List String → List String
  here' t = "QuorumCert" ∷ "verify" {- ∷ lsQC self-} ∷ t
