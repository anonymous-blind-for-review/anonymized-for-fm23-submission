{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

open import LibraBFT.Impl.OBM.Rust.RustTypes
open import Util.ByteString

module LibraBFT.Impl.OBM.ConfigHardCoded where

------------------------------------------------------------------------------

postulate -- TODO-1 ePOCHCHANGE
  ePOCHCHANGE : ByteString
--ePOCHCHANGE = "EPOCHCHANGE"

------------------------------------------------------------------------------

maxPrunedBlocksInMem : Usize
maxPrunedBlocksInMem = 10

roundInitialTimeoutMS : U64
roundInitialTimeoutMS = 3000

------------------------------------------------------------------------------
