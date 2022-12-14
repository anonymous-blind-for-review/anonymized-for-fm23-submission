{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

------------------------------------------------------------------------------
open import LibraBFT.Base.Types
import      LibraBFT.Impl.Consensus.BlockStorage.BlockStore      as BlockStore
import      LibraBFT.Impl.Consensus.BlockStorage.SyncManager     as SyncManager
import      LibraBFT.Impl.Consensus.ConsensusTypes.ExecutedBlock as ExecutedBlock
import      LibraBFT.Impl.Consensus.ConsensusTypes.SyncInfo      as SyncInfo
import      LibraBFT.Impl.Consensus.ConsensusTypes.Vote          as Vote
import      LibraBFT.Impl.Consensus.Liveness.ProposerElection    as ProposerElection
import      LibraBFT.Impl.Consensus.Liveness.ProposalGenerator   as ProposalGenerator
import      LibraBFT.Impl.Consensus.Liveness.RoundState          as RoundState
import      LibraBFT.Impl.Consensus.PersistentLivenessStorage    as PersistentLivenessStorage
import      LibraBFT.Impl.Consensus.SafetyRules.SafetyRules      as SafetyRules
open import LibraBFT.Impl.OBM.Logging.Logging
open import LibraBFT.ImplShared.Base.Types
open import LibraBFT.ImplShared.Consensus.Types
open import LibraBFT.ImplShared.Interface.Output
open import LibraBFT.ImplShared.Util.Crypto
open import LibraBFT.ImplShared.Util.Dijkstra.All
open import LibraBFT.Abstract.Types.EpochConfig UID NodeId
open import Optics.All
open import Util.ByteString
open import Util.Hash
import      Util.KVMap                                           as Map
open import Util.PKCS
open import Util.Prelude
-----------------------------------------------------------------------------
open import Data.String                                          using (String)
------------------------------------------------------------------------------

module LibraBFT.Impl.Consensus.RoundManager where

------------------------------------------------------------------------------

processCertificatesM : Instant ??? LBFT Unit

------------------------------------------------------------------------------

processCommitM : LedgerInfoWithSignatures ??? LBFT (List ExecutedBlock)
processCommitM finalityProof = pure []

------------------------------------------------------------------------------

generateProposalM
  : Instant ??? NewRoundEvent
  ??? LBFT (Either ErrLog ProposalMsg)

processNewRoundEventM : Instant ??? NewRoundEvent ??? LBFT Unit
processNewRoundEventM now nre@(NewRoundEvent???new r _ _) = do
  logInfo fakeInfo   -- (InfoNewRoundEvent nre)
  use (lRoundManager ??? pgAuthor) >>= ?? where
    nothing       ??? logErr fakeErr -- (here ["lRoundManager.pgAuthor", "Nothing"])
    (just author) ??? do
      v ??? ProposerElection.isValidProposer <$> use lProposerElection <*> pure author <*> pure r
      whenD v $ do
        rcvrs ??? use (lRoundManager ??? rmObmAllAuthors)
        generateProposalM now nre >>= ?? where
          -- (Left (ErrEpochEndedNoProposals t)) -> logInfoL (lEC.|.lPM) (here ("EpochEnded":t))
          (Left e)            ??? logErr (withErrCtx (here' ("Error generating proposal" ??? [])) e)
          (Right proposalMsg) ??? act (BroadcastProposal proposalMsg rcvrs)
 where
  here' : List String ??? List String
  here' t = "RoundManager" ??? "processNewRoundEventM" ??? t

abstract
  processNewRoundEventM-abs = processNewRoundEventM
  processNewRoundEventM-abs-??? : processNewRoundEventM-abs ??? processNewRoundEventM
  processNewRoundEventM-abs-??? = refl

generateProposalM now newRoundEvent =
  ProposalGenerator.generateProposalM now (newRoundEvent ^??? nreRound) ??????? ?? proposal ???
  SafetyRules.signProposalM proposal ??????? ?? signedProposal ???
  Right ??? ProposalMsg???new signedProposal <$> BlockStore.syncInfoM

------------------------------------------------------------------------------

ensureRoundAndSyncUpM : Instant ??? Round    ??? SyncInfo ??? Author ??? Bool ??? LBFT (Either ErrLog Bool)
processProposalM      : Block                                         ??? LBFT Unit
executeAndVoteM       : Block                                         ??? LBFT (Either ErrLog Vote)

-- external entry point
-- TODO-2: The sync info that the peer requests if it discovers that its round
-- state is behind the sender's should be sent as an additional argument, for now.
module processProposalMsgM (now : Instant) (pm : ProposalMsg) where
  step??? : LBFT Unit
  step??? : Author ??? LBFT Unit
  step??? : Either ErrLog Bool ??? LBFT Unit

  step??? =
    caseMD pm ^??? pmProposer of ?? where
      nothing ??? logInfo fakeInfo -- proposal with no author
      (just pAuthor) ??? step??? pAuthor

  step??? pAuthor =
        ensureRoundAndSyncUpM now (pm ^??? pmProposal ??? bRound) (pm ^??? pmSyncInfo)
                              pAuthor true >>= step???

  step??? =
        ?? where
          (Left e)      ??? logErr e
          (Right true)  ??? processProposalM (pm ^??? pmProposal)
          (Right false) ??? do
            currentRound ??? use (lRoundState ??? rsCurrentRound)
            logInfo fakeInfo -- dropping proposal for old round

abstract
  processProposalMsgM = processProposalMsgM.step???

  processProposalMsgM??? : processProposalMsgM ??? processProposalMsgM.step???
  processProposalMsgM??? = refl

------------------------------------------------------------------------------

module syncUpM (now : Instant) (syncInfo : SyncInfo) (author : Author) (_helpRemote : Bool) where
  step???       :                                LBFT (Either ErrLog Unit)
  step??? step??? : SyncInfo                     ??? LBFT (Either ErrLog Unit)
  step??? step??? : SyncInfo ??? ValidatorVerifier ??? LBFT (Either ErrLog Unit)

  here' : List String ??? List String

  step??? = do
    -- logEE (here' []) $ do
    localSyncInfo ??? BlockStore.syncInfoM
    -- TODO helpRemote
    step??? localSyncInfo

  step??? localSyncInfo = do
    ifD SyncInfo.hasNewerCertificates syncInfo localSyncInfo
      then step??? localSyncInfo
      else ok unit

  step??? localSyncInfo = do
        vv ??? use (lRoundManager ??? rmEpochState ??? esVerifier)
        SyncInfo.verifyM syncInfo vv ???^??? withErrCtx (here' []) ??????? ?? _ ??? step??? localSyncInfo vv

  step??? localSyncInfo vv =
          SyncManager.addCertsM {- reason -} syncInfo (BlockRetriever???new now author) ???^??? withErrCtx (here' [])
            ??????? ?? _ ??? step??? localSyncInfo vv

  step??? localSyncInfo vv = do
            processCertificatesM now
            ok unit

  here' t = "RoundManager" ??? "syncUpM" ??? t

syncUpM : Instant ??? SyncInfo ??? Author ??? Bool ??? LBFT (Either ErrLog Unit)
syncUpM = syncUpM.step???

------------------------------------------------------------------------------

-- This is the original ensureRoundAndSyncUpM function, closely mirroring the corresponding Haskell
-- code (modulo some minor logging differences).  For proofs about it, we actually use the version
-- in the module below, which is broken into steps for convenience (see
-- docs/PeerHandlerContracts.org).  The two are equivalent, as shown by the trivial proof in
-- ensureRoundAndSyncUpMSpec.ensureRoundAndSyncUp-???.  This is for demonstration purposes; we
-- generally consider it unnecessary to write the original code and prove it equivalent to the
-- version that is broken down into steps because (with appropriate formatting and indenting), it is
-- usually clear by inspection.
ensureRoundAndSyncUpM-original : Instant ??? Round ??? SyncInfo ??? Author ??? Bool ??? LBFT (Either ErrLog Bool)
ensureRoundAndSyncUpM-original now messageRound syncInfo author helpRemote = do
    currentRound ??? use (lRoundState ??? rsCurrentRound)
    ifD messageRound <? currentRound
      then ok false
      else do
        syncUpM now syncInfo author helpRemote ??????? ?? _ ??? do
          currentRound' ??? use (lRoundState ??? rsCurrentRound)
          ifD messageRound /= currentRound'
            then bail fakeErr -- error: after sync, round does not match local
            else ok true

module ensureRoundAndSyncUpM
  (now : Instant) (messageRound : Round) (syncInfo : SyncInfo) (author : Author) (helpRemote : Bool) where
  step??? : LBFT (Either ErrLog Bool)
  step??? : LBFT (Either ErrLog Bool)
  step??? : LBFT (Either ErrLog Bool)

  step??? = do
    currentRound ??? use (lRoundState ??? rsCurrentRound)
    ifD messageRound <? currentRound
      then ok false
      else step???

  step??? =
        syncUpM now syncInfo author helpRemote ??????? ?? _ ??? step???

  step??? = do
          currentRound' ??? use (lRoundState ??? rsCurrentRound)
          ifD messageRound /= currentRound'
            then bail fakeErr -- error: after sync, round does not match local
            else ok true

abstract
  ensureRoundAndSyncUpM = ensureRoundAndSyncUpM.step???
  ensureRoundAndSyncUpM-??? : ensureRoundAndSyncUpM ??? ensureRoundAndSyncUpM.step???
  ensureRoundAndSyncUpM-??? = refl

------------------------------------------------------------------------------

-- In Haskell, RoundManager.processSyncInfoMsgM is NEVER called.
--
-- When processing other messaging (i.e., Proposal and Vote) the first thing that happens,
-- before handling the specific message, is that ensureRoundAndSyncUpM is called to deal
-- with the SyncInfo message in the ProposalMsg or VoteMsg.
-- If a SyncInfo message ever did arrive by itself, all that would happen is that the
-- SyncInfo would be handled by ensureRoundAndSyncUpM (just like other messages).
-- And nothing else (except ensureRoundAndSyncUpM might do "catching up")
--
-- The only place the Haskell implementation uses SyncInfo only messages it during EpochChange.
-- And, in that case, the SyncInfo message is handled in the EpochManager, not here.

processSyncInfoMsgM : Instant ??? SyncInfo ??? Author ??? LBFT Unit
processSyncInfoMsgM now syncInfo peer =
  -- logEE (lEC.|.lSI) (here []) $
  ensureRoundAndSyncUpM now (syncInfo ^??? siHighestRound + 1) syncInfo peer false >>= ?? where
    (Left  e) ??? logErr (withErrCtx (here' []) e)
    (Right _) ??? pure unit
 where
  here' : List String ??? List String
  here' t = "RoundManager" ??? "processSyncInfoMsgM" ??? {- lsA peer ??? lsSI syncInfo ??? -} t

------------------------------------------------------------------------------

-- external entry point
processLocalTimeoutM : Instant ??? Epoch ??? Round ??? LBFT Unit
processLocalTimeoutM now obmEpoch round = do
  -- logEE lTO (here []) $
  ifMD (RoundState.processLocalTimeoutM now obmEpoch round) continue1 (pure unit)
 where
  here'     : List String ??? List String
  continue2 : LBFT Unit
  continue3 : (Bool ?? Vote) ??? LBFT Unit
  continue4 : Vote ??? LBFT Unit

  continue1 =
    ifMD (use (lRoundManager ??? rmSyncOnly))
      -- In Haskell, rmSyncOnly is ALWAYS false.
      -- It is used for an unimplemented "sync only" mode for nodes.
      -- "sync only" mode is an optimization for nodes catching up.
      (do si    ??? BlockStore.syncInfoM
          rcvrs ??? use (lRoundManager ??? rmObmAllAuthors)
          act (BroadcastSyncInfo si rcvrs))
      continue2

  continue2 =
    use (lRoundState ??? rsVoteSent) >>= ?? where
      (just vote) ???
        ifD (vote ^??? vVoteData ??? vdProposed ??? biRound == round)
          -- already voted in this round, so resend the vote, but with a timeout signature
          then continue3 (true , vote)
          else local-continue2-continue
      _ ??? local-continue2-continue
   where
    local-continue2-continue : LBFT Unit
    local-continue2-continue =
          -- have not voted in this round, so create and vote on NIL block with timeout signature
          ProposalGenerator.generateNilBlockM round >>= ?? where
            (Left         e) ??? logErr e
            (Right nilBlock) ???
              executeAndVoteM nilBlock >>= ?? where
                (Left        e) ??? logErr e
                (Right nilVote) ??? continue3 (false , nilVote)

  continue3 (useLastVote , timeoutVote) = do
    proposer ??? ProposerElection.getValidProposer <$> use lProposerElection <*> pure round
    logInfo fakeInfo
             -- (here [ if useLastVote then "already executed and voted, will send timeout vote"
             --                        else "generate nil timeout vote"
             --       , "expected proposer", lsA proposer ])
    if not (Vote.isTimeout timeoutVote)
      then
        (SafetyRules.signTimeoutM (Vote.timeout timeoutVote) >>= ?? where
          (Left  e) ??? logErr    (withErrCtx (here' []) e)
          (Right s) ??? continue4 (Vote.addTimeoutSignature timeoutVote s)) -- makes it a timeout vote
      else
        continue4 timeoutVote

  continue4 timeoutVote = do
    RoundState.recordVoteM timeoutVote
    timeoutVoteMsg ??? VoteMsg???new timeoutVote <$> BlockStore.syncInfoM
    rcvrs          ??? use (lRoundManager ??? rmObmAllAuthors)
    -- IMPL-DIFF this is BroadcastVote in Haskell (an alias)
    act (SendVote timeoutVoteMsg rcvrs)

  here' t = "RoundManager" ??? "processLocalTimeoutM" ??? {-lsE obmEpoch:lsR round-} t

------------------------------------------------------------------------------

processCertificatesM now = do
  syncInfo ??? BlockStore.syncInfoM
  maybeSMP-RWS (RoundState.processCertificatesM now syncInfo) unit (processNewRoundEventM now)

------------------------------------------------------------------------------

-- This function is broken into smaller pieces to aid in the verification
-- effort. The style of indentation used is to make side-by-side reading of the
-- Haskell prototype and Agda model easier.
module processProposalM (proposal : Block) where
  step??? : LBFT Unit
  step??? : BlockStore ??? (Either ObmNotValidProposerReason Unit) ??? LBFT Unit
  step??? : Either ErrLog Vote ??? LBFT Unit
  step??? : Vote ??? SyncInfo ??? LBFT Unit

  step??? = do
    bs ??? use lBlockStore
    vp ??? ProposerElection.isValidProposalM proposal
    step??? bs vp

  step??? bs vp =
    ifD??? isLeft vp ???
         logErr fakeErr -- proposer for block is not valid for this round
       ??? is-nothing (BlockStore.getQuorumCertForBlock (proposal ^??? bParentId) bs) ???
         logErr fakeErr -- QC of parent is not in BS
       ??? not (maybeS (BlockStore.getBlock (proposal ^??? bParentId) bs) false
              ?? parentBlock ???
                ??? parentBlock ^??? ebRound <???? proposal ^??? bRound ???) ???
         logErr fakeErr -- parentBlock < proposalRound
       ??? otherwise??? do
           executeAndVoteM proposal >>= step???

  step??? =  ?? where
             (Left e)     ??? logErr e
             (Right vote) ??? do
               RoundState.recordVoteM vote
               si ??? BlockStore.syncInfoM
               step??? vote si

  step??? vote si = do
               recipient ??? ProposerElection.getValidProposer
                           <$> use lProposerElection
                           <*> pure (proposal ^??? bRound + 1)
               act (SendVote (VoteMsg???new vote si) (recipient ??? []))
               -- TODO-2:                           mkNodesInOrder1 recipient

processProposalM = processProposalM.step???

------------------------------------------------------------------------------
module executeAndVoteM (b : Block) where
  step??? :                 LBFT (Either ErrLog Vote)
  step??? : ExecutedBlock ??? LBFT (Either ErrLog Vote)
  step??? : ExecutedBlock ??? LBFT (Either ErrLog Vote)
  step??? : Vote          ??? LBFT (Either ErrLog Vote)

  step??? =
    BlockStore.executeAndInsertBlockM b ???^??? withErrCtx ("" ??? []) ??????? step???

  step??? eb = do
    cr ??? use (lRoundState ??? rsCurrentRound)
    vs ??? use (lRoundState ??? rsVoteSent)
    so ??? use (lRoundManager ??? rmSyncOnly)
    ifD??? is-just vs ???
         bail fakeErr -- error: already voted this round
       ??? so ???
         bail fakeErr -- error: sync-only set
       ??? otherwise??? step??? eb

  step??? eb = do
           let maybeSignedVoteProposal' = ExecutedBlock.maybeSignedVoteProposal eb
           SafetyRules.constructAndSignVoteM maybeSignedVoteProposal' {- ???^??? logging -}
             ??????? step???

  step??? vote =   PersistentLivenessStorage.saveVoteM vote
             ??????? ?? _ ??? ok vote

executeAndVoteM = executeAndVoteM.step???

------------------------------------------------------------------------------

processVoteM     : Instant ??? Vote                ??? LBFT Unit
addVoteM         : Instant ??? Vote                ??? LBFT Unit
newQcAggregatedM : Instant ??? QuorumCert ??? Author ??? LBFT Unit
newTcAggregatedM : Instant ??? TimeoutCertificate  ??? LBFT Unit

processVoteMsgM : Instant ??? VoteMsg ??? LBFT Unit
processVoteMsgM now voteMsg = do
  -- TODO ensureRoundAndSyncUp
  processVoteM now (voteMsg ^??? vmVote)

processVoteM now vote =
  ifD not (Vote.isTimeout vote)
  then (do
    let nextRound = vote ^??? vVoteData ??? vdProposed ??? biRound + 1
    use (lRoundManager ??? pgAuthor) >>= ?? where
      nothing       ??? logErr fakeErr -- "lRoundManager.pgAuthor", "Nothing"
      (just author) ??? do
        v ??? ProposerElection.isValidProposer <$> use lProposerElection
                                             <*> pure author <*> pure nextRound
        if v then continue else logErr fakeErr) -- "received vote, but I am not proposer for round"
  else
    continue
 where
  continue : LBFT Unit
  continue = do
    let blockId = vote ^??? vVoteData ??? vdProposed ??? biId
    bs ??? use lBlockStore
    ifD (is-just (BlockStore.getQuorumCertForBlock blockId bs))
      then logInfo fakeInfo -- "block already has QC", "dropping unneeded vote"
      else do
      logInfo fakeInfo -- "before"
      addVoteM now vote
      pvA ??? use lPendingVotes
      logInfo fakeInfo -- "after"

addVoteM now vote = do
  bs ??? use lBlockStore
  maybeSD (bs ^??? bsHighestTimeoutCert) continue ?? tc ???
    ifD vote ^??? vRound == tc ^??? tcRound
      then logInfo fakeInfo -- "block already has TC", "dropping unneeded vote"
      else continue
 where
  continue : LBFT Unit
  continue = do
    verifier ??? use (rmEpochState ??? esVerifier)
    r ??? RoundState.insertVoteM vote verifier
    case r of ?? where
      (NewQuorumCertificate qc) ???
        newQcAggregatedM now qc (vote ^??? vAuthor)
      (NewTimeoutCertificate tc) ???
        newTcAggregatedM now tc
      _ ???
        pure unit

newQcAggregatedM now qc a =
  SyncManager.insertQuorumCertM qc (BlockRetriever???new now a) >>= ?? where
    (Left e)     ??? logErr e
    (Right unit) ??? processCertificatesM now

newTcAggregatedM now tc =
  BlockStore.insertTimeoutCertificateM tc >>= ?? where
    (Left e)     ??? logErr e
    (Right unit) ??? processCertificatesM now

------------------------------------------------------------------------------

-- TODO-1 PROVE IT TERMINATES
{-# TERMINATING #-}
mkRsp : BlockRetrievalRequest ??? (Author ?? Epoch ?? Round) ??? BlockStore ??? List Block ??? HashValue
      ??? BlockRetrievalResponse

-- external entry point
processBlockRetrievalRequestM : Instant ??? BlockRetrievalRequest ??? LBFT Unit
processBlockRetrievalRequestM _now request = do
  -- logEE lSI (here []) $ do
  use (lRoundManager ??? rmObmMe) >>= ?? where
    nothing ??? logErr fakeErr -- should not happen
    (just me) ??? continue me
 where

  continue : Author ??? LBFT Unit
  continue me = do
    e  ??? use (lRoundManager ??? rmSafetyRules ??? srPersistentStorage ??? pssSafetyData ??? sdEpoch)
    r  ??? use (lRoundManager ??? rmRoundState ??? rsCurrentRound)
    let meer = (me , e , r)
    bs ??? use lBlockStore
    act (SendBRP (request ^??? brqObmFrom) (mkRsp request meer bs [] (request ^??? brqBlockId)))

mkRsp request meer bs blocks id =
    if-dec length blocks <? request ^??? brqNumBlocks
    then
      (case BlockStore.getBlock id bs of ?? where
        (just executedBlock) ??? mkRsp request meer bs (blocks ++ (executedBlock ^??? ebBlock ??? []))
                                                     (executedBlock ^??? ebParentId)
        nothing ??? BlockRetrievalResponse???new meer
                    (if null blocks then BRSIdNotFound else BRSNotEnoughBlocks)
                    blocks)
    else BlockRetrievalResponse???new meer BRSSucceeded blocks

------------------------------------------------------------------------------

module start
  (now : Instant)
  (lastVoteSent : Maybe Vote)
  where

  step??? step???-abs : SyncInfo ??? LBFT Unit
  step??? step???-abs : Maybe NewRoundEvent ??? LBFT Unit
  step??? step??? step???-abs step???-abs : NewRoundEvent ??? LBFT Unit

  step??? : LBFT Unit
  step??? = do
    syncInfo ??? BlockStore.syncInfoM
    step???-abs syncInfo

  step??? syncInfo = do
    RoundState.processCertificatesM-abs now syncInfo >>= step???-abs

  here' : List String ??? List String
  here' t = "RoundManager" ??? "start" ??? t

  step??? = ?? where
      nothing    ???
        logErr fakeErr -- (here' ["Cannot jump start a round_state from existing certificates."]))
      (just nre) ??? step???-abs nre

  step??? nre = do
        maybeSMP (pure lastVoteSent) unit RoundState.recordVoteM
        step???-abs nre

  step??? nre = processNewRoundEventM-abs now nre -- error!("[RoundManager] Error during start: {:?}", e);

  abstract
    step???-abs = step???
    step???-abs-??? : step???-abs ??? step???
    step???-abs-??? = refl

    step???-abs = step???
    step???-abs-??? : step???-abs ??? step???
    step???-abs-??? = refl

    step???-abs = step???
    step???-abs-??? : step???-abs ??? step???
    step???-abs-??? = refl

    step???-abs = step???
    step???-abs-??? : step???-abs ??? step???
    step???-abs-??? = refl

abstract
  start-abs = start.step???
  start-abs-??? : start-abs ??? start.step???
  start-abs-??? = refl
